#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CodexUsageFloat"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/dist/release"
APP_VERSION="${APP_VERSION:-}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHS="${ARCHS:-arm64 x86_64}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"

if [[ ! "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "APP_VERSION is required and must use X.Y.Z format." >&2
  exit 1
fi

for required_arch in arm64 x86_64; do
  if [[ " $ARCHS " != *" $required_arch "* ]]; then
    echo "Release artifacts must include arm64 and x86_64 architectures." >&2
    exit 1
  fi
done

NOTARY_VALUES_SET=0
for value in "$APPLE_ID" "$APPLE_TEAM_ID" "$APPLE_APP_SPECIFIC_PASSWORD"; do
  if [[ -n "$value" ]]; then
    NOTARY_VALUES_SET=$((NOTARY_VALUES_SET + 1))
  fi
done

NOTARIZATION_ENABLED=0
if [[ "$NOTARY_VALUES_SET" -eq 3 && "$CODE_SIGN_IDENTITY" != "-" ]]; then
  NOTARIZATION_ENABLED=1
elif [[ "$NOTARY_VALUES_SET" -gt 0 ]]; then
  echo "Skipping notarization because the Apple credentials or signing identity are incomplete." >&2
fi

cd "$ROOT_DIR"

APP_VERSION="$APP_VERSION" \
BUILD_NUMBER="$BUILD_NUMBER" \
ARCHS="$ARCHS" \
CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  "$ROOT_DIR/scripts/package-app.sh" >/dev/null

BUILT_ARCHS="$(lipo -archs "$APP_PATH/Contents/MacOS/$APP_NAME")"
for requested_arch in $ARCHS; do
  if [[ " $BUILT_ARCHS " != *" $requested_arch "* ]]; then
    echo "Expected architecture $requested_arch, built: $BUILT_ARCHS" >&2
    exit 1
  fi
done

mkdir -p "$RELEASE_DIR"
ZIP_PATH="$RELEASE_DIR/$APP_NAME-$APP_VERSION-universal.zip"
DMG_PATH="$RELEASE_DIR/$APP_NAME-$APP_VERSION-universal.dmg"
CHECKSUM_PATH="$RELEASE_DIR/checksums.txt"
NOTARY_ZIP_PATH="$RELEASE_DIR/.notary-upload.zip"
DMG_STAGING_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$DMG_STAGING_DIR"
  rm -f "$NOTARY_ZIP_PATH"
}
trap cleanup EXIT

rm -f "$ZIP_PATH" "$DMG_PATH" "$CHECKSUM_PATH" "$NOTARY_ZIP_PATH"

if [[ "$NOTARIZATION_ENABLED" -eq 1 ]]; then
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ZIP_PATH"
  xcrun notarytool submit "$NOTARY_ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
  codesign --verify --deep --strict "$APP_PATH"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
else
  echo "Creating an unnotarized release. Configure Apple signing credentials for public distribution." >&2
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
ditto "$APP_PATH" "$DMG_STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME $APP_VERSION" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$CODE_SIGN_IDENTITY" "$DMG_PATH"
  codesign --verify --strict "$DMG_PATH"
fi

if [[ "$NOTARIZATION_ENABLED" -eq 1 ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH"
unzip -tq "$ZIP_PATH"

(
  cd "$RELEASE_DIR"
  shasum -a 256 "$(basename "$DMG_PATH")" "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "$DMG_PATH"
echo "$ZIP_PATH"
echo "$CHECKSUM_PATH"
