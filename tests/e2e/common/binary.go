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
	"os/exec"
	"path/filepath"
	"runtime"
)

// VfoxBinary returns the absolute path of the vfox executable under test.
//
// The VFOX_BIN environment variable wins when it is set. Otherwise vfox is
// looked up in PATH.
func VfoxBinary() (string, error) {
	if bin := os.Getenv("VFOX_BIN"); bin != "" {
		abs, err := filepath.Abs(bin)
		if err != nil {
			return "", fmt.Errorf("resolve VFOX_BIN %q: %w", bin, err)
		}
		if !isRegularFile(abs) {
			return "", fmt.Errorf("VFOX_BIN %q is not a file", abs)
		}
		return abs, nil
	}
	bin, err := exec.LookPath("vfox")
	if err != nil {
		return "", fmt.Errorf("vfox not found; set VFOX_BIN or put vfox on PATH: %w", err)
	}
	abs, err := filepath.Abs(bin)
	if err != nil {
		return "", fmt.Errorf("resolve vfox path %q: %w", bin, err)
	}
	return abs, nil
}

// ExecutableName returns name with the platform's executable suffix, so that
// "erl" becomes "erl.exe" on Windows.
func ExecutableName(name string) string {
	if runtime.GOOS == "windows" {
		return name + ".exe"
	}
	return name
}
