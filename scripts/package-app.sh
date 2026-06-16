#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AgentUsageFloat"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SWIFTC_BUILD_DIR="$ROOT_DIR/.build/swiftc-release"
BINARY_PATH="$ROOT_DIR/.build/release/$APP_NAME"

cd "$ROOT_DIR"

if swift build -c release; then
  BINARY_PATH="$ROOT_DIR/.build/release/$APP_NAME"
else
  echo "swift build failed; falling back to direct swiftc build." >&2
  rm -rf "$SWIFTC_BUILD_DIR"
  mkdir -p "$SWIFTC_BUILD_DIR"
  swiftc \
    -parse-as-library \
    -emit-module \
    -emit-library \
    -static \
    -module-name AgentUsageCore \
    Sources/AgentUsageCore/*.swift \
    -emit-module-path "$SWIFTC_BUILD_DIR/AgentUsageCore.swiftmodule" \
    -o "$SWIFTC_BUILD_DIR/libAgentUsageCore.a"
  swiftc \
    -parse-as-library \
    -I "$SWIFTC_BUILD_DIR" \
    -L "$SWIFTC_BUILD_DIR" \
    -lAgentUsageCore \
    Sources/AgentUsageFloat/*.swift \
    -o "$SWIFTC_BUILD_DIR/$APP_NAME"
  BINARY_PATH="$SWIFTC_BUILD_DIR/$APP_NAME"
fi

# Remove the pre-rename app bundle if it exists.
rm -rf "$ROOT_DIR/dist/CodexUsageFloat.app"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.local.agent-usage-float</string>
  <key>CFBundleName</key>
  <string>Agent Usage</string>
  <key>CFBundleDisplayName</key>
  <string>Agent Usage</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist"
echo "$APP_DIR"
