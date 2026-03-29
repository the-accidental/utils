#!/bin/bash
set -e

APP_NAME="BandBar"
EXECUTABLE_NAME="BandBar"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

echo "Building release binary..."
swift build -c release --disable-sandbox

echo "Creating .app bundle structure..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${CONTENTS_DIR}/Resources"

echo "Copying executable and icon..."
cp ".build/release/${EXECUTABLE_NAME}" "${MACOS_DIR}/"
cp "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns" "${CONTENTS_DIR}/Resources/AppIcon.icns"

echo "Creating Info.plist..."
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.iain.BandBar</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Done! You can now run or move ${APP_DIR}"
