#!/usr/bin/env bash
# Builds VitalsMac.app (release, ad-hoc signed) under ~/Library/Caches/VitalsMac/build.
# Usage: scripts/build-app.sh [--install]   (--install also copies it to ~/Applications)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Assembled outside the project on purpose: if the project sits in an iCloud-synced folder (Desktop,
# Documents), the sync service adds attributes to files mid-build and codesign then fails intermittently.
APP="$HOME/Library/Caches/VitalsMac/build/VitalsMac.app"

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

echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/VitalsMac.app"
    cp -R "$APP" "$HOME/Applications/VitalsMac.app"
    # An install that silently kept an older build is worse than a failed one.
    if ! cmp -s "$APP/Contents/MacOS/VitalsMac" "$HOME/Applications/VitalsMac.app/Contents/MacOS/VitalsMac"; then
        echo "error: installed binary differs from the build; quit VitalsMac and try again" >&2
        exit 1
    fi
    echo "Installed ~/Applications/VitalsMac.app (verified identical to the build)"
fi
