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
	"strings"
	"testing"
)

// helperEnv selects what TestHelperProcess does in the child process.
const helperEnv = "COMMON_TEST_HELPER"

// TestHelperProcess is not a real test. The tests below run the test binary
// with -test.run=^TestHelperProcess$ to get a child process with known output.
// That keeps these tests independent of sh and of any other installed tool.
func TestHelperProcess(t *testing.T) {
	switch os.Getenv(helperEnv) {
	case "success":
		fmt.Fprintln(os.Stdout, "helper-stdout")
		fmt.Fprintln(os.Stderr, "helper-stderr")
	case "cwd":
		wd, err := os.Getwd()
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(4)
		}
		fmt.Fprintln(os.Stdout, "cwd="+wd)
	case "failure":
		fmt.Fprintln(os.Stdout, "helper-failure-output")
		os.Exit(3)
	}
}

func helperCommand() []string {
	return []string{os.Args[0], "-test.run=^TestHelperProcess$"}
}

func TestRunReturnsCombinedOutput(t *testing.T) {
	env := append(os.Environ(), helperEnv+"=success")
	cmd := helperCommand()
	out := Run(t, env, "", cmd[0], cmd[1:]...)
	for _, want := range []string{"helper-stdout", "helper-stderr"} {
		if !strings.Contains(out, want) {
			t.Errorf("Run output does not contain %q:\n%s", want, out)
		}
	}
}

func TestRunUsesTheGivenDirectory(t *testing.T) {
	dir := t.TempDir()
	env := append(os.Environ(), helperEnv+"=cwd")
	cmd := helperCommand()
	out := Run(t, env, dir, cmd[0], cmd[1:]...)

	var got string
	for _, line := range strings.Split(out, "\n") {
		if rest, ok := strings.CutPrefix(strings.TrimSpace(line), "cwd="); ok {
			got = rest
		}
	}
	if got == "" {
		t.Fatalf("child did not report its directory:\n%s", out)
	}
	gotResolved, err := filepath.EvalSymlinks(got)
	if err != nil {
		t.Fatalf("resolve child directory %q: %v", got, err)
	}
	wantResolved, err := filepath.EvalSymlinks(dir)
	if err != nil {
		t.Fatalf("resolve directory %q: %v", dir, err)
	}
	if gotResolved != wantResolved {
		t.Fatalf("child ran in %q, want %q", gotResolved, wantResolved)
	}
}

func TestRunFailsWithOutputOnNonZeroExit(t *testing.T) {
	rec := &recordingTB{TB: t}
	env := append(os.Environ(), helperEnv+"=failure")
	cmd := helperCommand()
	Run(rec, env, "", cmd[0], cmd[1:]...)

	if rec.fatal == "" {
		t.Fatal("Run did not fail on exit status 3")
	}
	for _, want := range []string{"helper-failure-output", "exit status 3"} {
		if !strings.Contains(rec.fatal, want) {
			t.Errorf("failure message does not contain %q:\n%s", want, rec.fatal)
		}
	}
}

// recordingTB records the message of Fatalf instead of stopping the test.
type recordingTB struct {
	testing.TB
	fatal string
}

func (r *recordingTB) Helper() {}

func (r *recordingTB) Fatalf(format string, args ...any) {
	r.fatal = fmt.Sprintf(format, args...)
}
