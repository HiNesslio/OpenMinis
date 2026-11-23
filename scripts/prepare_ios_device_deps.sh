#!/usr/bin/env bash
# Prepare native device-only build dependencies required by Minis.xcodeproj.
# Run with bash (GitHub Contents API doesn't mark new scripts executable).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

if [ ! -e ".git" ]; then
  fail "This looks like a GitHub ZIP download. Native iSH submodules require a git clone. Use: git clone --recurse-submodules -b feat/ondevice-butler-foundation https://github.com/HiNesslio/OpenMinis.git"
fi

for cmd in xcodebuild xcrun git make go meson ninja unzip ditto; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing $cmd. Install Xcode and required build tools (see BUILDING.md)."
done

if [ ! -f src/ios/Configs/ProviderCustomization.xcconfig ]; then
  cp src/ios/Configs/ProviderCustomization.xcconfig.example \
     src/ios/Configs/ProviderCustomization.xcconfig
  echo "Created ProviderCustomization.xcconfig"
fi

echo "==> Updating nested iSH / PRoot submodules"
git submodule update --init --recursive
[ -d deps/ish ] && [ -e deps/ish/meson.build ] || \
  fail "iSH submodule is still missing or incomplete (deps/ish)."

# RootfsPatch is a checked-in iSH asset, not a compiled product.
# Stage it now so Xcode has the resource even if a later native build fails.
[ -f deps/ish/app/RootfsPatch.bundle/manifest.plist ] || \
  fail "Missing pinned iSH RootfsPatch bundle. Run git submodule update --init --recursive."
mkdir -p deps/resources
ditto deps/ish/app/RootfsPatch.bundle deps/resources/RootfsPatch.bundle
[ -f deps/resources/RootfsPatch.bundle/manifest.plist ] || \
  fail "Failed to stage RootfsPatch.bundle from iSH submodule."
echo "==> RootfsPatch.bundle staged"

echo "==> Building LAME, then FFmpeg XCFrameworks for iOS device"
bash deps/build_lame.sh
bash deps/build_ffmpeg.sh

echo "==> Building iSH and preparing the Alpine root filesystem"
bash deps/build_ish.sh
bash deps/prepare_alpine_rootfs.sh

echo "==> Building Rclone XCFramework"
bash deps/build_rclone_ios.sh

echo "==> Verifying required device frameworks"
for item in FFmpeg libavcodec libavformat libavutil libavfilter libswresample libswscale Rclone; do
  [ -d "deps/frameworks/$item.xcframework" ] || \
    fail "Missing deps/frameworks/$item.xcframework after build"
done
[ -s deps/resources/alpine-rootfs.zip ] || \
  fail "Missing deps/resources/alpine-rootfs.zip (run bash deps/prepare_alpine_rootfs.sh)"
[ -f deps/resources/RootfsPatch.bundle/manifest.plist ] || \
  fail "Missing deps/resources/RootfsPatch.bundle (run bash deps/build_ish.sh)"
for lib in libish.a libish_emu.a libfakefs.a libish_aot.a; do
  [ -s "deps/libs/$lib" ] || \
    fail "Missing deps/libs/$lib (run bash deps/build_ish.sh)"
done
if ! unzip -tq deps/resources/alpine-rootfs.zip >/dev/null; then
  fail "Alpine rootfs ZIP exists but is corrupt (rerun bash deps/prepare_alpine_rootfs.sh)"
fi

echo ""
echo "Native iOS dependencies are available. Open src/ios/Minis.xcodeproj"
echo "Choose a physical iPhone (device arm64) for the first build."
echo "Simulator builds need separate --simulator library builds."
