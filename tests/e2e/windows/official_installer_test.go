//go:build windows

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

package windows

import (
	"testing"

	"github.com/version-fox/vfox-erlang/tests/e2e/common"
)

// officialInstallerVersion is the version TestWindowsOfficialInstaller installs. The plugin
// has no source build on Windows: PostInstall runs the official installer into the sandbox.
const officialInstallerVersion = "25.3.2.12"

// TestWindowsOfficialInstaller installs Erlang/OTP through the plugin and checks the
// runtime with erl.exe, erlc.exe and the EEP-48 doc chunks. It is skipped in
// -short mode because the installer is large.
func TestWindowsOfficialInstaller(t *testing.T) {
	if testing.Short() {
		t.Skip("the installer download is large; run without -short")
	}
	version := officialInstallerVersion
	sb := common.NewSandbox(t)
	common.AddPlugin(t, sb, common.PluginZip(t, t.TempDir()), "erlang")

	common.InstallErlang(t, sb, version)
	common.UseGlobal(t, sb, version)

	common.AssertOTPRelease(t, sb, version)
	common.CompileAndRunHello(t, sb, version)
	common.AssertDocChunks(t, sb, version)
}
