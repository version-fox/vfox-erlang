//go:build linux

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

package linux

import (
	"os"
	"strings"
	"testing"
)

// defaultErlangVersion is the OTP version the Linux tests use unless
// E2E_ERLANG_VERSION says otherwise.
const defaultErlangVersion = "26.2.3"

// erlangVersion returns the Erlang/OTP version under test.
func erlangVersion() string {
	if v := strings.TrimSpace(os.Getenv("E2E_ERLANG_VERSION")); v != "" {
		return v
	}
	return defaultErlangVersion
}

// prebuiltOSRelease returns the USE_PREBUILT_OTP value for the prebuilt test.
//
// E2E_PREBUILT_OS overrides the detected release. Without it, the test reads
// VERSION_ID from /etc/os-release and runs only on Ubuntu 22.04 or 24.04, the
// releases that builds.hex.pm provides.
func prebuiltOSRelease(t *testing.T) string {
	t.Helper()
	if override := strings.TrimSpace(os.Getenv("E2E_PREBUILT_OS")); override != "" {
		return override
	}
	content, err := os.ReadFile("/etc/os-release")
	if err != nil {
		t.Skipf("cannot read /etc/os-release to pick a prebuilt release: %v", err)
	}
	versionID := osReleaseValue(string(content), "VERSION_ID")
	switch versionID {
	case "22.04", "24.04":
		return "ubuntu-" + versionID
	}
	t.Skipf("the prebuilt test needs Ubuntu 22.04 or 24.04, this system has VERSION_ID=%q; set E2E_PREBUILT_OS to override", versionID)
	return ""
}

// osReleaseValue returns the value of key in os-release content, with any
// surrounding quotes removed. It returns "" when key is absent.
func osReleaseValue(content, key string) string {
	for _, line := range strings.Split(content, "\n") {
		if rest, ok := strings.CutPrefix(strings.TrimSpace(line), key+"="); ok {
			return strings.Trim(rest, `"'`)
		}
	}
	return ""
}

func TestLinuxOSReleaseValueReadsQuotedAndBareValues(t *testing.T) {
	content := "NAME=\"Ubuntu\"\nVERSION_ID=\"22.04\"\nID=ubuntu\n"
	cases := map[string]string{
		"VERSION_ID": "22.04",
		"ID":         "ubuntu",
		"NAME":       "Ubuntu",
		"MISSING":    "",
	}
	for key, want := range cases {
		if got := osReleaseValue(content, key); got != want {
			t.Errorf("osReleaseValue(%s) = %q, want %q", key, got, want)
		}
	}
}
