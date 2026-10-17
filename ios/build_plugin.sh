#!/bin/bash
# Build ios/plugins/alarm_kit/alarm_kit.<debug|release>.xcframework against Godot 4.7.2 headers.
# Usage: ios/build_plugin.sh [debug|release]...   (default: both)
set -euo pipefail
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-27.0.0.app/Contents/Developer}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGIN="$ROOT/ios/plugins/alarm_kit"
CACHE="$HOME/Library/Caches/sunflower"
GODOT="$CACHE/godot-4.7.2-stable"
if [ ! -d "$GODOT" ]; then
  mkdir -p "$CACHE"
  curl -sSL https://github.com/godotengine/godot/archive/refs/tags/4.7.2-stable.tar.gz | tar xz -C "$CACHE"
fi
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

compile() {
  local variant=$1 target=$2 sdk=$3 out=$4
  local defines=(-DIOS_ENABLED -DAPPLE_EMBEDDED_ENABLED -DUNIX_ENABLED)
  if [ "$variant" = debug ]; then
    defines+=(-DDEBUG_ENABLED)
  else
    defines+=(-DNDEBUG)
  fi
  xcrun clang++ -c -std=gnu++17 -fno-exceptions -fobjc-arc -target "$target" -isysroot "$sdk" -O2 \
    "${defines[@]}" -I"$GODOT" -I"$GODOT/platform/ios" -I"$PLUGIN" \
    -o "$out.o" "$PLUGIN/alarm_kit_plugin.mm"
  libtool -static -o "$out.a" "$out.o"
}

VARIANTS=("$@")
[ ${#VARIANTS[@]} -eq 0 ] && VARIANTS=(debug release)
for v in "${VARIANTS[@]}"; do
  dir="$WORK/$v"
  mkdir -p "$dir/dev" "$dir/sim"
  compile "$v" arm64-apple-ios26.0 "$IOS_SDK" "$dir/dev_arm64"
  compile "$v" arm64-apple-ios26.0-simulator "$SIM_SDK" "$dir/sim_arm64"
  compile "$v" x86_64-apple-ios26.0-simulator "$SIM_SDK" "$dir/sim_x86_64"
  cp "$dir/dev_arm64.a" "$dir/dev/libalarm_kit.a"
  lipo -create "$dir/sim_arm64.a" "$dir/sim_x86_64.a" -output "$dir/sim/libalarm_kit.a"
  out="$PLUGIN/alarm_kit.$v.xcframework"
  rm -rf "$out"
  xcodebuild -create-xcframework \
    -library "$dir/dev/libalarm_kit.a" \
    -library "$dir/sim/libalarm_kit.a" \
    -output "$out" > /dev/null
  echo "BUILT $out"
done
