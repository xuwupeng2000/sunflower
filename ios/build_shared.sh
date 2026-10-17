#!/bin/bash
# Rebuild ios/plugins/alarm_kit/SunflowerShared.xcframework from ios/shared/*.swift.
set -euo pipefail
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-27.0.0.app/Contents/Developer}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/ios/shared"
OUT="$ROOT/ios/plugins/alarm_kit/SunflowerShared.xcframework"
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
SOURCES=("$SRC/SunflowerShared.swift" "$SRC/SnoozeStore.swift" "$SRC/AlarmKitBridge.swift")
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

build_slice() {
  local target=$1 sdk=$2 dest=$3
  local fw="$dest/SunflowerShared.framework"
  local mod="$fw/Modules/SunflowerShared.swiftmodule"
  mkdir -p "$fw/Headers" "$mod"
  local triple=${target%%-*}
  xcrun swiftc -emit-library -o "$fw/SunflowerShared" -module-name SunflowerShared \
    -emit-module -emit-module-path "$mod/${triple}.swiftmodule" \
    -emit-module-interface-path "$mod/${triple}.swiftinterface" \
    -emit-private-module-interface-path "$mod/${triple}.private.swiftinterface" \
    -emit-objc-header -emit-objc-header-path "$fw/Headers/SunflowerShared-Swift.h" \
    -target "$target" -sdk "$sdk" -O -enable-library-evolution -swift-version 5 \
    -framework AlarmKit -framework AppIntents -framework SwiftUI -framework ActivityKit -framework UIKit \
    -Xlinker -install_name -Xlinker @rpath/SunflowerShared.framework/SunflowerShared \
    "${SOURCES[@]}"
  cat > "$fw/Modules/module.modulemap" <<'MM'
framework module SunflowerShared {
  header "SunflowerShared-Swift.h"
  export *
}
MM
  local platform=iPhoneOS
  [[ "$sdk" == *Simulator* ]] && platform=iPhoneSimulator
  cat > "$fw/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.xinli.sunflower.shared</string>
<key>CFBundleName</key><string>SunflowerShared</string>
<key>CFBundleExecutable</key><string>SunflowerShared</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>26.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>${platform}</string></array>
</dict></plist>
PLIST
}

build_slice arm64-apple-ios26.0 "$IOS_SDK" "$WORK/dev"
build_slice arm64-apple-ios26.0-simulator "$SIM_SDK" "$WORK/sim_arm"
build_slice x86_64-apple-ios26.0-simulator "$SIM_SDK" "$WORK/sim_x86"
mkdir -p "$WORK/sim/SunflowerShared.framework"
cp -R "$WORK/sim_arm/SunflowerShared.framework/." "$WORK/sim/SunflowerShared.framework/"
lipo -create \
  "$WORK/sim_arm/SunflowerShared.framework/SunflowerShared" \
  "$WORK/sim_x86/SunflowerShared.framework/SunflowerShared" \
  -output "$WORK/sim/SunflowerShared.framework/SunflowerShared"
rsync -a "$WORK/sim_x86/SunflowerShared.framework/Modules/SunflowerShared.swiftmodule/" \
  "$WORK/sim/SunflowerShared.framework/Modules/SunflowerShared.swiftmodule/"
rm -rf "$OUT"
xcodebuild -create-xcframework \
  -framework "$WORK/dev/SunflowerShared.framework" \
  -framework "$WORK/sim/SunflowerShared.framework" \
  -output "$OUT" > /dev/null
echo "REBUILT $OUT"
