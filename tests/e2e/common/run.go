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
	"os/exec"
	"strings"
	"testing"
)

// RunOutput executes name with args in dir, or in the current directory when dir
// is empty. It returns the combined stdout and stderr together with the error
// from the process. env is the full environment of the child process; nil means
// inherit.
func RunOutput(env []string, dir, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = env
	out, err := cmd.CombinedOutput()
	return string(out), err
}

// Run is RunOutput for tests. A non-zero exit fails the test, and the captured
// output is attached to the failure message.
func Run(t testing.TB, env []string, dir, name string, args ...string) string {
	t.Helper()
	out, err := RunOutput(env, dir, name, args...)
	if err != nil {
		t.Fatalf("command failed: %s\nerror: %v\noutput:\n%s",
			strings.Join(append([]string{name}, args...), " "), err, out)
		return ""
	}
	return out
}
