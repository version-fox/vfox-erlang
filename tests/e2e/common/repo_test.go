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
	"os"
	"path/filepath"
	"testing"
)

func TestRepoRootFindsThePluginFromThisPackage(t *testing.T) {
	// An empty E2E_REPO makes RepoRoot walk up from the package directory.
	t.Setenv("E2E_REPO", "")
	got, err := RepoRoot()
	if err != nil {
		t.Fatalf("RepoRoot() error: %v", err)
	}
	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Getwd: %v", err)
	}
	// This package lives in tests/e2e/common, three levels below the repository root.
	want := filepath.Clean(filepath.Join(wd, "..", "..", ".."))
	if got != want {
		t.Fatalf("RepoRoot() = %q, want %q", got, want)
	}
	if !isRegularFile(filepath.Join(got, "metadata.lua")) {
		t.Fatalf("RepoRoot() = %q, which has no metadata.lua", got)
	}
}

func TestFindRepoRootWalksUpToThePluginRoot(t *testing.T) {
	root := t.TempDir()
	makePluginRoot(t, root)
	deep := filepath.Join(root, "a", "b", "c")
	if err := os.MkdirAll(deep, 0o755); err != nil {
		t.Fatal(err)
	}
	got, err := findRepoRoot(deep)
	if err != nil {
		t.Fatalf("findRepoRoot(%q) error: %v", deep, err)
	}
	if got != root {
		t.Fatalf("findRepoRoot(%q) = %q, want %q", deep, got, root)
	}
}

func TestIsPluginRootNeedsMetadataAndHooksDirectory(t *testing.T) {
	dir := t.TempDir()
	if isPluginRoot(dir) {
		t.Fatal("an empty directory is not a plugin root")
	}
	writeTestFile(t, filepath.Join(dir, "metadata.lua"), "PLUGIN = {}\n")
	if isPluginRoot(dir) {
		t.Fatal("metadata.lua alone is not a plugin root")
	}
	if err := os.Mkdir(filepath.Join(dir, "hooks"), 0o755); err != nil {
		t.Fatal(err)
	}
	if !isPluginRoot(dir) {
		t.Fatal("metadata.lua with a hooks/ directory should be a plugin root")
	}
}

func TestIsPluginRootRejectsHooksFile(t *testing.T) {
	dir := t.TempDir()
	writeTestFile(t, filepath.Join(dir, "metadata.lua"), "PLUGIN = {}\n")
	writeTestFile(t, filepath.Join(dir, "hooks"), "not a directory")
	if isPluginRoot(dir) {
		t.Fatal("a hooks file is not a hooks/ directory")
	}
}

func TestRepoRootHonorsE2ERepo(t *testing.T) {
	root := t.TempDir()
	makePluginRoot(t, root)
	t.Setenv("E2E_REPO", root)
	got, err := RepoRoot()
	if err != nil {
		t.Fatalf("RepoRoot() error: %v", err)
	}
	if got != root {
		t.Fatalf("RepoRoot() = %q, want E2E_REPO %q", got, root)
	}
}

func TestRepoRootRejectsInvalidE2ERepo(t *testing.T) {
	t.Setenv("E2E_REPO", t.TempDir())
	if got, err := RepoRoot(); err == nil {
		t.Fatalf("RepoRoot() = %q, want an error for an E2E_REPO without the plugin files", got)
	}
}

// makePluginRoot creates the two entries that mark a plugin root.
func makePluginRoot(t *testing.T, dir string) {
	t.Helper()
	writeTestFile(t, filepath.Join(dir, "metadata.lua"), "PLUGIN = {}\n")
	if err := os.Mkdir(filepath.Join(dir, "hooks"), 0o755); err != nil {
		t.Fatal(err)
	}
}

// writeTestFile writes content to path, failing the test on error.
func writeTestFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
