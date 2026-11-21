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
	"testing"

	"github.com/version-fox/vfox-erlang/tests/e2e/common"
)

// TestLinuxPrebuiltInstall installs a prebuilt Erlang/OTP from builds.hex.pm
// with USE_PREBUILT_OTP. It uses a numeric version, so it also covers the
// OTP- prefix that the download URL needs. The download is large, so the test
// is skipped in -short mode.
func TestLinuxPrebuiltInstall(t *testing.T) {
	if testing.Short() {
		t.Skip("prebuilt download is large; run without -short")
	}
	osRelease := prebuiltOSRelease(t)
	version := erlangVersion()
	sb := common.NewSandbox(t)
	common.AddPlugin(t, sb, common.PluginZip(t, t.TempDir()), "erlang")

	t.Logf("installing prebuilt erlang@%s for %s", version, osRelease)
	common.InstallErlang(t, sb, version, "USE_PREBUILT_OTP="+osRelease)
	common.UseGlobal(t, sb, version)

	common.AssertOTPRelease(t, sb, version)
}
