#!/usr/bin/env bash
# Builds a release ClaudeRing.app.zip in ./build/release/
# Requires: full Xcode installed (not just CLI tools) — xcodebuild
# Usage: ./release.sh
set -euo pipefail

cd "$(dirname "$0")"

# Regenerate Xcode project to pick up any new files
xcodegen generate >/dev/null

rm -rf build/release
mkdir -p build/release

echo "→ Archiving Release build..."
xcodebuild \
  -project ClaudeRing.xcodeproj \
  -scheme ClaudeRing \
  -configuration Release \
  -archivePath build/release/ClaudeRing.xcarchive \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  ONLY_ACTIVE_ARCH=NO \
  archive >/dev/null

echo "→ Exporting .app..."
cat > build/release/export-options.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
EOF

xcodebuild \
  -exportArchive \
  -archivePath build/release/ClaudeRing.xcarchive \
  -exportPath build/release/export \
  -exportOptionsPlist build/release/export-options.plist >/dev/null

echo "→ Ad-hoc signing..."
codesign --force --sign - \
  --entitlements ClaudeRing/Resources/ClaudeRing.entitlements \
  build/release/export/ClaudeRing.app

echo "→ Zipping..."
cd build/release/export
zip -qr ../ClaudeRing.app.zip ClaudeRing.app
cd ../../..

SIZE=$(du -h build/release/ClaudeRing.app.zip | cut -f1)
echo ""
echo "✓ Built: build/release/ClaudeRing.app.zip ($SIZE)"
echo ""
echo "Test it:"
echo "  open build/release/export/ClaudeRing.app"
echo ""
echo "Distribute it:"
echo "  Upload build/release/ClaudeRing.app.zip to GitHub Releases"
