#!/bin/bash
# Compila Claude Usage y genera build/ClaudeUsage.dmg
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Claude Usage"
APP="build/$APP_NAME.app"
DMG="build/ClaudeUsage.dmg"

echo "→ Compilando…"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/ClaudeUsage"

echo "→ Armando $APP_NAME.app…"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ClaudeUsage"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "→ Generando ícono…"
swift scripts/make_icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

echo "→ Firmando (ad-hoc)…"
codesign --force --deep --sign - "$APP"

echo "→ Creando DMG…"
mkdir -p build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "$APP_NAME" -srcfolder build/dmg -ov -format UDZO "$DMG" >/dev/null
rm -rf build/dmg build/AppIcon.iconset

echo "✓ Listo: $DMG"

# ./build.sh --install: reemplaza la app en /Applications y la vuelve a abrir.
if [[ "${1:-}" == "--install" ]]; then
    echo "→ Instalando en /Applications…"
    pkill -x ClaudeUsage || true
    sleep 1
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    open "/Applications/$APP_NAME.app"
    echo "✓ Instalada y abierta"
fi
