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
	"archive/zip"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPluginZipContainsOnlyRuntimeFiles(t *testing.T) {
	repo := MustRepoRoot(t)
	zipPath := PluginZip(t, t.TempDir())
	if !filepath.IsAbs(zipPath) {
		t.Fatalf("PluginZip() = %q, want an absolute path", zipPath)
	}
	if filepath.Base(zipPath) != "vfox-erlang-e2e.zip" {
		t.Fatalf("PluginZip() = %q, want a vfox-erlang-e2e.zip file", zipPath)
	}

	r, err := zip.OpenReader(zipPath)
	if err != nil {
		t.Fatalf("open %s: %v", zipPath, err)
	}
	defer r.Close()

	got := map[string]bool{}
	for _, f := range r.File {
		rel, ok := strings.CutPrefix(f.Name, PluginZipPrefix)
		if !ok {
			t.Errorf("entry %q is not under %s", f.Name, PluginZipPrefix)
			continue
		}
		got[rel] = true
	}

	want := expectedPluginEntries(t, repo)
	for name := range want {
		if !got[name] {
			t.Errorf("plugin zip is missing %q", name)
		}
	}
	for name := range got {
		if !want[name] {
			t.Errorf("plugin zip has unexpected entry %q", name)
		}
	}
	// Spot-check that development-only paths never reach the archive.
	for _, forbidden := range []string{".git/", "website/", "tests/", "README.md", "Injection.lua"} {
		for name := range got {
			if strings.HasPrefix(name, forbidden) || name == forbidden {
				t.Errorf("plugin zip must not contain %q", name)
			}
		}
	}
}

func TestPluginZipKeepsFileContents(t *testing.T) {
	repo := MustRepoRoot(t)
	zipPath := PluginZip(t, t.TempDir())

	r, err := zip.OpenReader(zipPath)
	if err != nil {
		t.Fatalf("open %s: %v", zipPath, err)
	}
	defer r.Close()

	for _, rel := range []string{"metadata.lua", "assets/hello.erl"} {
		want, err := os.ReadFile(filepath.Join(repo, filepath.FromSlash(rel)))
		if err != nil {
			t.Fatalf("read %s: %v", rel, err)
		}
		got := readZipEntry(t, r, PluginZipPrefix+rel)
		if string(got) != string(want) {
			t.Errorf("%s in the zip differs from the repository copy", rel)
		}
	}
}

// expectedPluginEntries lists what the zip must contain, computed from the
// repository: the three top-level files, plus every file and directory under
// hooks/ and lib/. Directory names end with a slash.
func expectedPluginEntries(t *testing.T, repo string) map[string]bool {
	t.Helper()
	want := map[string]bool{
		"metadata.lua":     true,
		"LICENSE":          true,
		"assets/hello.erl": true,
	}
	for _, dir := range pluginDirs {
		root := filepath.Join(repo, dir)
		err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if path != root && strings.HasPrefix(d.Name(), ".") {
				if d.IsDir() {
					return filepath.SkipDir
				}
				return nil
			}
			rel, err := filepath.Rel(repo, path)
			if err != nil {
				return err
			}
			name := filepath.ToSlash(rel)
			if d.IsDir() {
				name += "/"
			}
			want[name] = true
			return nil
		})
		if err != nil {
			t.Fatalf("walk %s: %v", root, err)
		}
	}
	return want
}

// readZipEntry returns the content of the named entry, failing the test if it is absent.
func readZipEntry(t *testing.T, r *zip.ReadCloser, name string) []byte {
	t.Helper()
	for _, f := range r.File {
		if f.Name != name {
			continue
		}
		rc, err := f.Open()
		if err != nil {
			t.Fatalf("open zip entry %s: %v", name, err)
		}
		defer rc.Close()
		data, err := io.ReadAll(rc)
		if err != nil {
			t.Fatalf("read zip entry %s: %v", name, err)
		}
		return data
	}
	t.Fatalf("zip entry %s not found", name)
	return nil
}
