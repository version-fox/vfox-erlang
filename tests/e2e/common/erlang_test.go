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

import "testing"

func TestOTPMajorTakesTheFirstComponent(t *testing.T) {
	cases := map[string]string{
		"26.2.3":    "26",
		"25.3.2.12": "25",
		"27":        "27",
		"":          "",
	}
	for version, want := range cases {
		if got := OTPMajor(version); got != want {
			t.Errorf("OTPMajor(%q) = %q, want %q", version, got, want)
		}
	}
}

func TestFirstLineSkipsBlankLines(t *testing.T) {
	cases := map[string]string{
		"":                 "",
		"26\n":             "26",
		"\n\n  26  \n":     "26",
		"warning: x\n26\n": "warning: x",
	}
	for out, want := range cases {
		if got := firstLine(out); got != want {
			t.Errorf("firstLine(%q) = %q, want %q", out, got, want)
		}
	}
}
