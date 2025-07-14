#!/bin/bash
echo "Testing macOS prebuilt versions..."

echo "1. Testing without USE_PREBUILT_OTP (should use source versions):"
cd /Users/yeshan333/.version-fox/plugin/erlang
export USE_PREBUILT_OTP=""
curl -s "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/versions.txt" | head -5

echo ""
echo "2. Testing with USE_PREBUILT_OTP for macOS (should use macOS prebuilt versions):"
export USE_PREBUILT_OTP="1"
curl -s "https://fastly.jsdelivr.net/gh/version-fox/vfox-erlang@main/assets/macos_prebuilt_versions.txt" | head -5

echo ""
echo "3. Testing macOS prebuilt versions file exists:"
ls -la assets/macos_prebuilt_versions.txt

echo ""
echo "4. First few lines of macOS prebuilt versions:"
head -5 assets/macos_prebuilt_versions.txt
