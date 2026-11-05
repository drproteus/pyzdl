#!/usr/bin/env bash
#
# Build a macOS .app bundle for pyZDL.
#
# Targets Apple Silicon (arm64) by default. The bundle is code signed, which is
# required for arm64 binaries to launch on modern macOS; it uses an ad-hoc
# signature ("-") unless you pass --sign with a real identity. Pass --dmg to
# also package the result into a .dmg.
#
# Requirements: macOS, Xcode Command Line Tools (iconutil, codesign, hdiutil),
# and uv.
#
# Usage:
#   scripts/build-macos.sh [options]
#
# Options:
#   --dmg             Also create a .dmg alongside the .app
#   --universal2      Build a universal2 (arm64 + x86_64) app instead of arm64
#   --no-clean        Keep py2app's intermediate build directory
#   --sign IDENTITY   Code sign with IDENTITY (default: ad-hoc "-")
#   -h, --help        Show this help

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="pyZDL"
APP_BUNDLE="$ROOT/dist/$APP_NAME.app"
ICNS="$ROOT/assets/pyzdl-launcher.icns"
ICONSET="$ROOT/build/icon.iconset"

ARCH="arm64"
BUILD_DMG=0
DO_CLEAN=1
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

usage() {
    cat <<'EOF'
Usage: scripts/build-macos.sh [options]

Options:
  --dmg             Also create a .dmg alongside the .app
  --universal2      Build a universal2 (arm64 + x86_64) app instead of arm64
  --no-clean        Keep py2app's intermediate build directory
  --sign IDENTITY   Code sign with IDENTITY (default: ad-hoc "-")
  -h, --help        Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dmg) BUILD_DMG=1 ;;
        --universal2) ARCH="universal2" ;;
        --no-clean) DO_CLEAN=0 ;;
        --sign) CODESIGN_IDENTITY="$2"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: this script must run on macOS." >&2
    exit 1
fi

for tool in uv iconutil codesign file; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "error: required tool '$tool' not found on PATH." >&2
        exit 1
    fi
done
command -v hdiutil >/dev/null 2>&1 || BUILD_DMG=0

echo "==> Syncing dependencies (uv sync)"
uv sync

echo "==> Generating app icon ($ICNS)"
mkdir -p "$(dirname "$ICONSET")"
uv run python - <<'PY'
import os
from PIL import Image
from scripts.draw_launcher_icon import draw_icon

iconset = os.path.join("build", "icon.iconset")
os.makedirs(iconset, exist_ok=True)
icon = draw_icon()  # 1024x1024 RGBA

sizes = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}
for name, side in sizes.items():
    icon.resize((side, side), Image.LANCZOS).save(os.path.join(iconset, name))
PY
iconutil -c icns "$ICONSET" -o "$ICNS"

if [[ "$DO_CLEAN" -eq 1 ]]; then
    echo "==> Cleaning previous build"
    rm -rf "$ROOT/build" "$ROOT/dist"
fi

echo "==> Building $APP_NAME.app (arch: $ARCH)"
export PY2APP_ARCH="$ARCH"
uv run python setup.py py2app

echo "==> Repairing dylibs (macholib trailing garbage)"
uv run python scripts/repair_macho.py "$APP_BUNDLE"

echo "==> Code signing ($CODESIGN_IDENTITY)"
# Clear existing signatures first: macholib can leave stale LC_CODE_SIGNATURE
# data that makes `codesign --force --sign` fail; trimming trailing garbage
# (above) makes `--remove-signature` work again.
find "$APP_BUNDLE/Contents" -type f \( -name '*.dylib' -o -name '*.so' \) -print0 \
    | xargs -0 -n1 codesign --remove-signature 2>/dev/null || true

# Sign inside-out: standalone Mach-O binaries, then frameworks, then the app.
find "$APP_BUNDLE/Contents" -type f \( -name '*.dylib' -o -name '*.so' \) -print0 \
    | xargs -0 -n1 codesign --force --sign "$CODESIGN_IDENTITY"
find "$APP_BUNDLE/Contents" -type d -name '*.framework' -print0 \
    | xargs -0 -n1 codesign --force --sign "$CODESIGN_IDENTITY"
codesign --force --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE"

echo "==> Verifying bundle"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" 2>&1 | tail -3
file "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [[ "$BUILD_DMG" -eq 1 ]]; then
    DMG="$ROOT/dist/$APP_NAME-$ARCH.dmg"
    echo "==> Creating $DMG"
    hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG"
    echo
    echo "Done: $DMG"
else
    echo
    echo "Done: $APP_BUNDLE"
fi
