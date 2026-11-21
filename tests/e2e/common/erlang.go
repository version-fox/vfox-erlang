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
	"strings"
	"testing"
)

const (
	// otpReleaseExpr prints the major OTP release. It has no double quotes, so
	// it reaches erl intact through Windows command-line quoting.
	otpReleaseExpr = "io:put_chars(erlang:system_info(otp_release)), io:nl()."
	// docChunksExpr renders the docs of the lists module through shell_docs,
	// which needs the EEP-48 doc chunks.
	docChunksExpr = "erlang:display(shell_docs:get_doc(lists))."
	// docChunksMarker appears in the rendered lists docs of both OTP 25 and 26.
	docChunksMarker = "functions for list processing"
	// helloMarker is printed by hello:hello_world/0.
	helloMarker = "hello, world"
)

// OTPMajor returns the major release of an OTP version: "26" for "26.2.3".
func OTPMajor(version string) string {
	major, _, _ := strings.Cut(version, ".")
	return major
}

// ErlangTool runs an Erlang tool, erl or erlc, from erlang@version through
// `vfox exec` in dir, and returns its combined output.
func ErlangTool(t testing.TB, sb Sandbox, dir, version, tool string, args ...string) string {
	t.Helper()
	execArgs := append([]string{"exec", "erlang@" + version, "--", ExecutableName(tool)}, args...)
	return VfoxWith(t, sb.Env(), dir, execArgs...)
}

// AssertOTPRelease checks that erl reports the major release of version. The
// first non-blank line of erl's output must start with that major release.
func AssertOTPRelease(t testing.TB, sb Sandbox, version string) {
	t.Helper()
	// Every erl call ends with `-s init stop`. If an -eval expression crashes,
	// -noshell would otherwise keep the emulator running and hang the test.
	out := ErlangTool(t, sb, sb.Work, version, "erl",
		"-noshell", "-eval", otpReleaseExpr, "-s", "init", "stop")
	want := OTPMajor(version)
	if got := firstLine(out); !strings.HasPrefix(got, want) {
		t.Fatalf("erl reports OTP release %q, want it to start with %q\noutput:\n%s", got, want, out)
	}
}

// CompileAndRunHello compiles assets/hello.erl with erlc and runs
// hello:hello_world/0 with erl. Both steps work on a copy of the source in a
// fresh directory, so the repository is left unchanged.
func CompileAndRunHello(t testing.TB, sb Sandbox, version string) {
	t.Helper()
	src := filepath.Join(MustRepoRoot(t), "assets", "hello.erl")
	dir := t.TempDir()
	copyFile(t, src, filepath.Join(dir, "hello.erl"))

	ErlangTool(t, sb, dir, version, "erlc", "hello.erl")
	out := ErlangTool(t, sb, dir, version, "erl",
		"-noshell", "-s", "hello", "hello_world", "-s", "init", "stop")
	if !strings.Contains(out, helloMarker) {
		t.Fatalf("hello:hello_world/0 did not print %q\noutput:\n%s", helloMarker, out)
	}
	// hello_world/0 also prints the OTP release it runs on, which must match.
	if want := "You are using Erlang/OTP " + OTPMajor(version); !strings.Contains(out, want) {
		t.Fatalf("hello:hello_world/0 did not print %q\noutput:\n%s", want, out)
	}
}

// AssertDocChunks checks that the installation carries EEP-48 doc chunks: the
// docs of the lists module must render through shell_docs.
func AssertDocChunks(t testing.TB, sb Sandbox, version string) {
	t.Helper()
	out := ErlangTool(t, sb, sb.Work, version, "erl",
		"-noshell", "-eval", docChunksExpr, "-s", "init", "stop")
	if !strings.Contains(out, docChunksMarker) {
		t.Fatalf("shell_docs did not render the lists docs; the build may lack doc chunks\noutput:\n%s", out)
	}
}

// firstLine returns the first non-blank line of out, with surrounding space removed.
func firstLine(out string) string {
	for _, line := range strings.Split(out, "\n") {
		if line = strings.TrimSpace(line); line != "" {
			return line
		}
	}
	return ""
}

// copyFile copies src to dst, replacing dst if it exists.
func copyFile(t testing.TB, src, dst string) {
	t.Helper()
	data, err := os.ReadFile(src)
	if err != nil {
		t.Fatalf("read %s: %v", src, err)
	}
	if err := os.WriteFile(dst, data, 0o644); err != nil {
		t.Fatalf("write %s: %v", dst, err)
	}
}
