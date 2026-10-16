#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="K589Config"
DIST="${ROOT}/dist"
APP_BUNDLE="${DIST}/${APP_NAME}.app"
BIN_OUT="${ROOT}/.build/apple/Products/Release/${APP_NAME}"
# Fallback path used by single-arch swift build
BIN_FALLBACK="${ROOT}/.build/release/${APP_NAME}"

VERSION="${VERSION:-0.1.0}"
ARCH_LABEL="${ARCH_LABEL:-universal}"

rm -rf "$DIST"
mkdir -p "$DIST"

echo "==> Building ${APP_NAME} (${ARCH_LABEL})"
if [[ "${ARCH_LABEL}" == "universal" ]]; then
  swift build -c release --arch arm64 --arch x86_64
else
  # Host architecture only (CI smoke / local).
  swift build -c release
  ARCH_LABEL="$(uname -m)"
fi

BIN=""
if [[ -x "$BIN_OUT" ]]; then
  BIN="$BIN_OUT"
elif [[ -x "$BIN_FALLBACK" ]]; then
  BIN="$BIN_FALLBACK"
else
  # SPM may place the binary under a triple directory
  BIN="$(find "${ROOT}/.build" -type f -name "$APP_NAME" -path '*/release/*' | head -n 1 || true)"
fi

if [[ -z "${BIN}" || ! -x "${BIN}" ]]; then
  echo "error: release binary not found" >&2
  find "${ROOT}/.build" -type f -name "$APP_NAME" 2>/dev/null || true
  exit 1
fi

echo "==> Packaging ${APP_BUNDLE} from ${BIN}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# SPM resource bundle (keyboard skin, etc.)
BUNDLE_SRC="$(find "${ROOT}/.build" -type d -name "${APP_NAME}_${APP_NAME}.bundle" | head -n 1 || true)"
if [[ -n "${BUNDLE_SRC}" ]]; then
  cp -R "${BUNDLE_SRC}" "${APP_BUNDLE}/Contents/Resources/"
fi

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.fedecarpi.k589config</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Redragon K589 Config</string>
  <key>CFBundleDisplayName</key>
  <string>Redragon K589 Config</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so Gatekeeper is less angry on download (still unsigned / not notarized).
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "${APP_BUNDLE}" || true
fi

ZIP_NAME="${APP_NAME}-${VERSION}-macos-${ARCH_LABEL}.zip"
(
  cd "$DIST"
  ditto -c -k --keepParent "${APP_NAME}.app" "${ZIP_NAME}"
  shasum -a 256 "${ZIP_NAME}" | tee "${ZIP_NAME}.sha256"
)

echo "==> Done: ${DIST}/${ZIP_NAME}"
ls -la "$DIST"
