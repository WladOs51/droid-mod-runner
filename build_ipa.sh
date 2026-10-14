#!/bin/bash
set -e

APP_NAME="DroidModRunner"
MIN_IOS="14.0"
BUILD_DIR="./build_output"
PAYLOAD_DIR="${BUILD_DIR}/Payload"
APP_BUNDLE="${PAYLOAD_DIR}/${APP_NAME}.app"
IPA_OUTPUT="./${APP_NAME}_iOS14.ipa"

rm -rf "${BUILD_DIR}" "${IPA_OUTPUT}"
mkdir -p "${APP_BUNDLE}"

SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
TARGET_TRIPLE="arm64-apple-ios${MIN_IOS}"

cat << 'EOF' > "${APP_BUNDLE}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DroidModRunner</string>
    <key>CFBundleIdentifier</key>
    <string>com.custom.droidmodrunner</string>
    <key>CFBundleName</key>
    <string>DroidModRunner</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>14.0</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportsDocumentBrowser</key>
    <true/>
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <false/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Android Package Archive</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>com.android.package-archive</string>
                <string>com.android.split-package-archive</string>
                <string>com.android.xapk-archive</string>
            </array>
        </dict>
    </array>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.android.package-archive</string>
            <key>UTTypeDescription</key>
            <string>Android APK Mod Package</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.archive</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>apk</string>
                    <string>APK</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.android.split-package-archive</string>
            <key>UTTypeDescription</key>
            <string>Split APKS Bundle</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.archive</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>apks</string>
                    <string>APKS</string>
                </array>
            </dict>
        </dict>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.android.xapk-archive</string>
            <key>UTTypeDescription</key>
            <string>XAPK Game Mod Container</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.archive</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>xapk</string>
                    <string>XAPK</string>
                </array>
            </dict>
        </dict>
    </array>
</dict>
</plist>
EOF

cat << 'EOF' > "${BUILD_DIR}/Entitlements.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>*.com.custom.droidmodrunner</string>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>dynamic-codesigning</key>
    <true/>
    <key>get-task-allow</key>
    <true/>
</dict>
</plist>
EOF

xcrun --sdk iphoneos clang \
    -target "${TARGET_TRIPLE}" \
    -isysroot "${SDK_PATH}" \
    -O2 -c android_core.c \
    -o "${BUILD_DIR}/android_core.o"

xcrun --sdk iphoneos swiftc \
    -target "${TARGET_TRIPLE}" \
    -sdk "${SDK_PATH}" \
    -O \
    -parse-as-library \
    -import-objc-header Bridging-Header.h \
    DroidModRunnerApp.swift \
    "${BUILD_DIR}/android_core.o" \
    -lcompression \
    -o "${APP_BUNDLE}/${APP_NAME}"

codesign --force --sign - --entitlements "${BUILD_DIR}/Entitlements.plist" --timestamp=none "${APP_BUNDLE}"

cd "${BUILD_DIR}"
zip -r -q "../${APP_NAME}_iOS14.ipa" Payload
cd ..
