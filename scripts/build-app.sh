#!/usr/bin/env bash
# Builds build/VitalsMac.app (release, ad-hoc signed).
# Usage: scripts/build-app.sh [--install]   (--install also copies it to ~/Applications)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="build/VitalsMac.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/VitalsMac"
[ -x "$BIN" ] || { echo "error: release binary not found at $BIN" >&2; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/VitalsMac"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Extended attributes (Finder info, quarantine) make codesign refuse the bundle.
xattr -cr "$APP"

# Ad-hoc signature: enough to run locally and to register as a login item.
codesign --force --sign - "$APP"
codesign --verify --verbose=2 "$APP"

echo "Built $ROOT/$APP"

if [ "${1:-}" = "--install" ]; then
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/VitalsMac.app"
    cp -R "$APP" "$HOME/Applications/VitalsMac.app"
    echo "Installed ~/Applications/VitalsMac.app"
fi
