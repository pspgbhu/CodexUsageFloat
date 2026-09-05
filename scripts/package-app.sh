#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CodexUsageFloat"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SWIFTC_BUILD_DIR="$ROOT_DIR/.build/swiftc-release"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"
APP_VERSION="${APP_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHS="${ARCHS:-}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "APP_VERSION must use X.Y.Z format: $APP_VERSION" >&2
  exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "BUILD_NUMBER must be a positive integer: $BUILD_NUMBER" >&2
  exit 1
fi

REQUESTED_ARCHS=()
if [[ -n "$ARCHS" ]]; then
  read -r -a REQUESTED_ARCHS <<< "$ARCHS"
  for requested_arch in "${REQUESTED_ARCHS[@]}"; do
    if [[ "$requested_arch" != "arm64" && "$requested_arch" != "x86_64" ]]; then
      echo "Unsupported architecture: $requested_arch" >&2
      exit 1
    fi
  done
fi

cd "$ROOT_DIR"

SWIFT_BUILD_ARGS=(-c release)
if [[ -n "$ARCHS" ]]; then
  for requested_arch in "${REQUESTED_ARCHS[@]}"; do
    SWIFT_BUILD_ARGS+=(--arch "$requested_arch")
  done
fi

if swift build "${SWIFT_BUILD_ARGS[@]}"; then
  BINARY_DIR="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)"
  BINARY_PATH="$BINARY_DIR/$APP_NAME"
else
  echo "swift build failed; falling back to direct swiftc build." >&2
  rm -rf "$SWIFTC_BUILD_DIR"
  mkdir -p "$SWIFTC_BUILD_DIR"

  FALLBACK_ARCHS=()
  if [[ -n "$ARCHS" ]]; then
    FALLBACK_ARCHS=("${REQUESTED_ARCHS[@]}")
  else
    FALLBACK_ARCHS=("$(uname -m)")
  fi

  FALLBACK_BINARIES=()
  for fallback_arch in "${FALLBACK_ARCHS[@]}"; do
    ARCH_BUILD_DIR="$SWIFTC_BUILD_DIR/$fallback_arch"
    TARGET="$fallback_arch-apple-macos13.0"
    mkdir -p "$ARCH_BUILD_DIR"

    swiftc \
      -target "$TARGET" \
      -parse-as-library \
      -emit-module \
      -emit-library \
      -static \
      -module-name AgentUsageCore \
      Sources/AgentUsageCore/*.swift \
      -emit-module-path "$ARCH_BUILD_DIR/AgentUsageCore.swiftmodule" \
      -o "$ARCH_BUILD_DIR/libAgentUsageCore.a"
    swiftc \
      -target "$TARGET" \
      -parse-as-library \
      -I "$ARCH_BUILD_DIR" \
      -L "$ARCH_BUILD_DIR" \
      -lAgentUsageCore \
      Sources/CodexUsageFloat/*.swift \
      -o "$ARCH_BUILD_DIR/$APP_NAME"
    FALLBACK_BINARIES+=("$ARCH_BUILD_DIR/$APP_NAME")
  done

  BINARY_PATH="$SWIFTC_BUILD_DIR/$APP_NAME"
  if [[ ${#FALLBACK_BINARIES[@]} -eq 1 ]]; then
    cp "${FALLBACK_BINARIES[0]}" "$BINARY_PATH"
  else
    lipo -create "${FALLBACK_BINARIES[@]}" -output "$BINARY_PATH"
  fi
fi

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Built executable not found: $BINARY_PATH" >&2
  exit 1
fi

# Remove the pre-rename app bundle if it exists.
rm -rf "$ROOT_DIR/dist/AgentUsageFloat.app"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BINARY_PATH" "$MACOS_DIR/$APP_NAME"
if [[ -f "$ICON_FILE" ]]; then
  cp "$ICON_FILE" "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.local.codex-usage-float</string>
  <key>CFBundleName</key>
  <string>CodexUsageFloat</string>
  <key>CFBundleDisplayName</key>
  <string>CodexUsageFloat</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
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

if [[ -n "$CODE_SIGN_IDENTITY" ]]; then
  if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP_DIR"
  else
    codesign \
      --force \
      --options runtime \
      --timestamp \
      --sign "$CODE_SIGN_IDENTITY" \
      "$APP_DIR"
  fi
  codesign --verify --deep --strict "$APP_DIR"
fi

echo "$APP_DIR"
