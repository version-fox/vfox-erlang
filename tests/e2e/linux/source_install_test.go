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

// TestLinuxSourceInstall builds Erlang/OTP from source through the plugin, then
// checks the runtime with erl, erlc and the EEP-48 doc chunks. The build takes a
// long time, so the test is skipped in -short mode.
func TestLinuxSourceInstall(t *testing.T) {
	if testing.Short() {
		t.Skip("source builds take a long time; run without -short")
	}
	version := erlangVersion()
	sb := common.NewSandbox(t)
	common.AddPlugin(t, sb, common.PluginZip(t, t.TempDir()), "erlang")

	flags := common.MakeFlags()
	t.Logf("building erlang@%s from source with MAKEFLAGS=%s", version, flags)
	common.InstallErlang(t, sb, version, "MAKEFLAGS="+flags)
	common.UseGlobal(t, sb, version)

	common.AssertOTPRelease(t, sb, version)
	common.CompileAndRunHello(t, sb, version)
	common.AssertDocChunks(t, sb, version)
}
