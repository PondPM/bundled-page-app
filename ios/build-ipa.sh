#!/usr/bin/env bash
# Builds bundled-page.ipa on macOS with Xcode.
#   ./build-ipa.sh                 -> unsigned IPA (re-sign with AltStore/Sideloadly, or for CI)
#   TEAM_ID=ABCDE12345 ./build-ipa.sh  -> signed IPA (EXPORT_METHOD=development|ad-hoc|app-store, default development)
set -euo pipefail
cd "$(dirname "$0")"
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate
rm -rf build
if [ -n "${TEAM_ID:-}" ]; then
  xcodebuild -project App.xcodeproj -scheme App -configuration Release -sdk iphoneos \
    -archivePath build/App.xcarchive archive DEVELOPMENT_TEAM="$TEAM_ID" -allowProvisioningUpdates
  cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>${EXPORT_METHOD:-development}</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
  xcodebuild -exportArchive -archivePath build/App.xcarchive -exportPath build/export \
    -exportOptionsPlist build/ExportOptions.plist -allowProvisioningUpdates
  cp build/export/*.ipa "bundled-page.ipa"
else
  xcodebuild -project App.xcodeproj -scheme App -configuration Release -sdk iphoneos \
    -archivePath build/App.xcarchive archive CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
  mkdir -p build/Payload
  cp -R build/App.xcarchive/Products/Applications/App.app build/Payload/
  (cd build && zip -qry ../"bundled-page.ipa" Payload)
fi
echo "Built $(pwd)/bundled-page.ipa"
