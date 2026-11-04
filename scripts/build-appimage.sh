#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

arch="${ARCH:-x86_64}"
appdir="build/pyZDL.AppDir"
output="dist/pyZDL-$arch.AppImage"

uv sync

uv run pyinstaller \
    --noconfirm \
    --clean \
    --onedir \
    --name pyZDL \
    --specpath build \
    --add-data "$root/assets:assets" \
    cli.py

rm -rf "$appdir"
mkdir -p "$appdir/usr/bin"
cp -a dist/pyZDL/. "$appdir/usr/bin/"
cp assets/pyzdl-launcher.png "$appdir/pyzdl-launcher.png"
ln -s pyzdl-launcher.png "$appdir/.DirIcon"

cat > "$appdir/pyZDL.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=pyZDL
Comment=A launcher for GZDoom and other Doom source ports
Exec=AppRun
Icon=pyzdl-launcher
Categories=Game;
Terminal=false
EOF

cat > "$appdir/AppRun" <<'EOF'
#!/bin/sh
here="$(dirname "$(readlink -f "$0")")"
if [ $# -eq 0 ]; then
    set -- gui
fi
exec "$here/usr/bin/pyZDL" "$@"
EOF
chmod +x "$appdir/AppRun"

tool="${APPIMAGETOOL:-}"
if [ -z "$tool" ]; then
    if command -v appimagetool >/dev/null 2>&1; then
        tool="$(command -v appimagetool)"
    else
        tool="build/tools/appimagetool-$arch.AppImage"
        if [ ! -x "$tool" ]; then
            mkdir -p "$(dirname "$tool")"
            curl -fL -o "$tool" \
                "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$arch.AppImage"
            chmod +x "$tool"
        fi
    fi
fi

# Lets appimagetool run where FUSE is unavailable, such as containers and CI.
export APPIMAGE_EXTRACT_AND_RUN=1
ARCH="$arch" "$tool" "$appdir" "$output"

echo "Built $output"
