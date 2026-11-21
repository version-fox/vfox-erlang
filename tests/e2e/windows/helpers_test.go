//go:build windows

// Copyright 2026 vfox-erlang contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package windows

import (
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"testing"
	"time"
)

// defaultProgramFiles is used when %ProgramFiles% is not set.
const defaultProgramFiles = `C:\Program Files`

// minInstallerSize is a sanity bound for the official installer. The 26.2.3
// installer is about 146 MB, so anything much smaller is a broken download.
const minInstallerSize = 50 << 20

// installNamePrefixes are the lower-case prefixes of the directory names the
// official installer uses for Erlang/OTP.
var installNamePrefixes = []string{"erlang otp", "erl"}

// programFilesDir returns the directory the installer uses by default.
func programFilesDir() string {
	if dir := os.Getenv("ProgramFiles"); dir != "" {
		return dir
	}
	return defaultProgramFiles
}

// listErlangDirs returns the directories directly under root whose names look
// like an Erlang/OTP install, whether or not they hold a working install.
func listErlangDirs(root string) (map[string]bool, error) {
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil, err
	}
	dirs := map[string]bool{}
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		name := strings.ToLower(entry.Name())
		for _, prefix := range installNamePrefixes {
			if strings.HasPrefix(name, prefix) {
				dirs[filepath.Join(root, entry.Name())] = true
				break
			}
		}
	}
	return dirs, nil
}

// mustListErlangDirs is listErlangDirs for tests: it fails the test on error.
func mustListErlangDirs(t *testing.T, root string) map[string]bool {
	t.Helper()
	dirs, err := listErlangDirs(root)
	if err != nil {
		t.Fatalf("list %s: %v", root, err)
	}
	return dirs
}

// newDirs returns the directories in after that are not in before, sorted.
func newDirs(before, after map[string]bool) []string {
	added := map[string]bool{}
	for dir := range after {
		if !before[dir] {
			added[dir] = true
		}
	}
	return sortedKeys(added)
}

// sortedKeys returns the keys of m in sorted order.
func sortedKeys(m map[string]bool) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

// hasErlExe reports whether dir holds bin\erl.exe.
func hasErlExe(dir string) bool {
	info, err := os.Stat(filepath.Join(dir, "bin", "erl.exe"))
	return err == nil && info.Mode().IsRegular()
}

// downloadInstaller fetches the official Windows installer for version into a
// temporary directory and returns its path.
func downloadInstaller(t *testing.T, version string) string {
	t.Helper()
	name := "otp_win64_" + version + ".exe"
	url := "https://github.com/erlang/otp/releases/download/OTP-" + version + "/" + name
	dest := filepath.Join(t.TempDir(), name)

	req, err := http.NewRequestWithContext(t.Context(), http.MethodGet, url, nil)
	if err != nil {
		t.Fatalf("build request for %s: %v", url, err)
	}
	client := &http.Client{Timeout: 30 * time.Minute}
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("download %s: %v", url, err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("download %s: HTTP %d, want 200", url, resp.StatusCode)
	}

	f, err := os.Create(dest)
	if err != nil {
		t.Fatalf("create %s: %v", dest, err)
	}
	n, copyErr := io.Copy(f, resp.Body)
	closeErr := f.Close()
	if copyErr != nil {
		t.Fatalf("write %s: %v", dest, copyErr)
	}
	if closeErr != nil {
		t.Fatalf("close %s: %v", dest, closeErr)
	}
	if n < minInstallerSize {
		t.Fatalf("installer %s is %d bytes, want at least %d", url, n, minInstallerSize)
	}
	return dest
}

// commandOutput runs a program and returns its combined stdout and stderr.
func commandOutput(name string, args ...string) ([]byte, error) {
	return exec.Command(name, args...).CombinedOutput()
}

// silentInstall runs the installer with /S, which installs without prompts to
// the default location when no /D= is given.
func silentInstall(t *testing.T, installer string) {
	t.Helper()
	out, err := commandOutput(installer, "/S")
	if err != nil {
		t.Fatalf("silent install with %s failed: %v\n%s", installer, err, out)
	}
}

// silentUninstall runs uninstall.exe /S from dir and waits for dir to disappear.
// It runs in cleanup, so problems are logged instead of failing the test.
func silentUninstall(t *testing.T, dir string) {
	t.Helper()
	uninstaller := filepath.Join(dir, "uninstall.exe")
	if _, err := os.Stat(uninstaller); err != nil {
		t.Logf("cleanup: no uninstaller in %s: %v", dir, err)
		return
	}
	out, err := commandOutput(uninstaller, "/S")
	if err != nil {
		t.Logf("cleanup: uninstall %s failed: %v\n%s", dir, err, out)
		return
	}
	// Some uninstallers copy themselves elsewhere and return before the files
	// are gone, so wait for the directory to disappear.
	deadline := time.Now().Add(5 * time.Minute)
	for {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			return
		}
		if time.Now().After(deadline) {
			t.Logf("cleanup: %s still exists five minutes after uninstall", dir)
			return
		}
		time.Sleep(2 * time.Second)
	}
}

// uninstallNewDirs silently uninstalls the Erlang/OTP installs that appeared
// under root after the snapshot before.
func uninstallNewDirs(t *testing.T, root string, before map[string]bool) {
	t.Helper()
	after, err := listErlangDirs(root)
	if err != nil {
		t.Logf("cleanup: list %s: %v", root, err)
		return
	}
	for _, dir := range newDirs(before, after) {
		silentUninstall(t, dir)
	}
}
