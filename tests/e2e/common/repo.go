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

package common

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

// RepoRoot returns the absolute path of the vfox-erlang plugin repository.
//
// The E2E_REPO environment variable wins when it is set. Otherwise the search
// starts at the current directory and walks up until it finds a directory that
// holds both metadata.lua and hooks/.
func RepoRoot() (string, error) {
	if repo := os.Getenv("E2E_REPO"); repo != "" {
		abs, err := filepath.Abs(repo)
		if err != nil {
			return "", fmt.Errorf("resolve E2E_REPO %q: %w", repo, err)
		}
		if !isPluginRoot(abs) {
			return "", fmt.Errorf("E2E_REPO %q is not a vfox-erlang plugin root (metadata.lua and hooks/ are required)", abs)
		}
		return abs, nil
	}
	wd, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("get working directory: %w", err)
	}
	return findRepoRoot(wd)
}

// MustRepoRoot is RepoRoot for tests: it fails the test when no root is found.
func MustRepoRoot(t testing.TB) string {
	t.Helper()
	root, err := RepoRoot()
	if err != nil {
		t.Fatalf("%v", err)
	}
	return root
}

// findRepoRoot walks up from start and returns the first plugin root it finds.
func findRepoRoot(start string) (string, error) {
	dir := start
	for {
		if isPluginRoot(dir) {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("no vfox-erlang plugin root (metadata.lua and hooks/) above %s; set E2E_REPO", start)
		}
		dir = parent
	}
}

// isPluginRoot reports whether dir holds the plugin's metadata.lua and hooks/ directory.
func isPluginRoot(dir string) bool {
	if !isRegularFile(filepath.Join(dir, "metadata.lua")) {
		return false
	}
	info, err := os.Stat(filepath.Join(dir, "hooks"))
	return err == nil && info.IsDir()
}

// isRegularFile reports whether path exists and is a regular file.
func isRegularFile(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.Mode().IsRegular()
}
