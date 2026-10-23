#!/usr/bin/env bash
# Builds a release binary and wraps it in "build/One by One.app", which you
# can open from Finder or drag into /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product OneByOne
bin="$(swift build -c release --show-bin-path)/OneByOne"
app="build/One by One.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/OneByOne"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>One by One</string>
    <key>CFBundleDisplayName</key>
    <string>One by One</string>
    <key>CFBundleIdentifier</key>
    <string>local.onebyone.app</string>
    <key>CFBundleExecutable</key>
    <string>OneByOne</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc signing is enough to run it on this Mac.
codesign --force --sign - "$app" >/dev/null
echo "$app"
