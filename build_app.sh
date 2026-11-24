#!/bin/zsh
set -e

APP_NAME="MyCalendar"
BUNDLE_DIR="./${APP_NAME}.app"
STAGE_DIR="/tmp/${APP_NAME}.app"
CONTENTS_DIR="${STAGE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

export CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache
export TMPDIR=/tmp

echo "1. Building ${APP_NAME} (Universal Binary: arm64 + x86_64)..."

# Build ARM64
swift build -c release --disable-sandbox --triple arm64-apple-macosx
BIN_ARM="$(swift build -c release --disable-sandbox --show-bin-path --triple arm64-apple-macosx)/${APP_NAME}"
cp "${BIN_ARM}" /tmp/MyCalendar_bin_arm64

# Build x86_64 (Intel)
swift build -c release --disable-sandbox --triple x86_64-apple-macosx
BIN_X86="$(swift build -c release --disable-sandbox --show-bin-path --triple x86_64-apple-macosx)/${APP_NAME}"
cp "${BIN_X86}" /tmp/MyCalendar_bin_x86

# Merge with lipo
lipo -create -output /tmp/MyCalendar_bin_universal /tmp/MyCalendar_bin_arm64 /tmp/MyCalendar_bin_x86
echo "Universal binary created successfully:"
file /tmp/MyCalendar_bin_universal

# Prepare app bundle
rm -rf "${STAGE_DIR}" "${BUNDLE_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp /tmp/MyCalendar_bin_universal "${MACOS_DIR}/${APP_NAME}"
if [ -f "windows-app/assets/icon.png" ]; then
    sips -s format icns "windows-app/assets/icon.png" --out "${RESOURCES_DIR}/AppIcon.icns"
fi

cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ko</string>
    <key>CFBundleExecutable</key>
    <string>MyCalendar</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.jis.MyCalendar</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>나만의 캘린더</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

xattr -cr "${STAGE_DIR}"
codesign --force --deep --sign - "${STAGE_DIR}"
cp -R "${STAGE_DIR}" "${BUNDLE_DIR}"

echo "2. Built ${BUNDLE_DIR} successfully!"

echo "3. Creating MyCalendar-Mac.zip..."
rm -f MyCalendar-Mac.zip
zip -r -y -q MyCalendar-Mac.zip "${BUNDLE_DIR}"

echo "Done build_app.sh!"
