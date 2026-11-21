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
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// PluginZipPrefix is the top-level directory inside the plugin zip. It follows the
// layout of GitHub archives. vfox strips a single top-level directory on unpack,
// so a flat zip would install the same way.
const PluginZipPrefix = "vfox-erlang-e2e/"

// pluginFiles are the files vfox needs at runtime, relative to the repository root.
var pluginFiles = []string{"metadata.lua", "LICENSE", "assets/hello.erl"}

// pluginDirs are the directories vfox needs at runtime. Every regular file under
// them is packed.
var pluginDirs = []string{"hooks", "lib"}

// PluginZip packs the plugin's runtime files into outDir/vfox-erlang-e2e.zip and
// returns its absolute path. Nothing else goes in: no .git, website, tests,
// README or development files.
func PluginZip(t testing.TB, outDir string) string {
	t.Helper()
	repo := MustRepoRoot(t)
	zipPath, err := filepath.Abs(filepath.Join(outDir, "vfox-erlang-e2e.zip"))
	if err != nil {
		t.Fatalf("resolve plugin zip path: %v", err)
	}
	if err := writePluginZip(repo, zipPath); err != nil {
		t.Fatalf("write plugin zip %s: %v", zipPath, err)
	}
	return zipPath
}

func writePluginZip(repo, zipPath string) error {
	f, err := os.Create(zipPath)
	if err != nil {
		return err
	}
	zw := zip.NewWriter(f)
	for _, rel := range pluginFiles {
		if err := addZipFile(zw, repo, rel); err != nil {
			_ = zw.Close()
			_ = f.Close()
			return err
		}
	}
	for _, dir := range pluginDirs {
		if err := addZipTree(zw, repo, dir); err != nil {
			_ = zw.Close()
			_ = f.Close()
			return err
		}
	}
	if err := zw.Close(); err != nil {
		_ = f.Close()
		return err
	}
	return f.Close()
}

// addZipTree adds the directory rel and everything below it, in lexical order.
// Hidden files are skipped.
func addZipTree(zw *zip.Writer, repo, rel string) error {
	root := filepath.Join(repo, filepath.FromSlash(rel))
	return filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if path != root && strings.HasPrefix(d.Name(), ".") {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		entry, err := filepath.Rel(repo, path)
		if err != nil {
			return err
		}
		if d.IsDir() {
			info, err := d.Info()
			if err != nil {
				return err
			}
			return addZipDir(zw, filepath.ToSlash(entry), info)
		}
		return addZipFile(zw, repo, filepath.ToSlash(entry))
	})
}

// addZipDir writes a directory entry, for example "vfox-erlang-e2e/hooks/".
func addZipDir(zw *zip.Writer, rel string, info fs.FileInfo) error {
	hdr, err := zip.FileInfoHeader(info)
	if err != nil {
		return err
	}
	hdr.Name = PluginZipPrefix + rel + "/"
	_, err = zw.CreateHeader(hdr)
	return err
}

// addZipFile writes the regular file rel, given with forward slashes, to the zip.
func addZipFile(zw *zip.Writer, repo, rel string) error {
	abs := filepath.Join(repo, filepath.FromSlash(rel))
	info, err := os.Stat(abs)
	if err != nil {
		return err
	}
	data, err := os.ReadFile(abs)
	if err != nil {
		return err
	}
	hdr, err := zip.FileInfoHeader(info)
	if err != nil {
		return err
	}
	hdr.Name = PluginZipPrefix + rel
	hdr.Method = zip.Deflate
	w, err := zw.CreateHeader(hdr)
	if err != nil {
		return err
	}
	_, err = w.Write(data)
	return err
}
