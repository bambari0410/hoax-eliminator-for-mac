#!/bin/sh
# ./build.sh          -> ".build/Hoax Eliminator for Mac.app" for this Mac's architecture
# ./build.sh test     -> run the matching self-check (fake filesystem, nothing real is touched)
# ./build.sh test --e2e | --plant | --verify | --clean  -> real ~/Library test with a dummy app, see Tests/E2E.swift
# ./build.sh package  -> ../dist/Hoax-Eliminator-for-Mac-<version>.zip
#                        universal (Apple Silicon + Intel), ad-hoc signed, NOT notarized: users clear the quarantine
#                        flag once with xattr, or use Open Anyway in System Settings (see Packaging/INSTALL.txt)
set -e
cd "$(dirname "$0")"
mkdir -p .build
MIN=13.0  # keep in sync with LSMinimumSystemVersion in Info.plist

if [ "$1" = test ]; then
  shift
  swiftc Sources/Cleaner.swift Sources/Security.swift Sources/Privileged.swift Tests/*.swift -o .build/check
  exec .build/check "$@"
fi

ARCHS=$(uname -m)
[ "$1" = package ] && ARCHS="arm64 x86_64"

APP=".build/Hoax Eliminator for Mac.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/"
# Icon is drawn by Tools/icon.swift; redrawn only when the script changes.
if [ Tools/icon.swift -nt .build/AppIcon.icns ]; then
  swift Tools/icon.swift .build/AppIcon.iconset && iconutil -c icns .build/AppIcon.iconset -o .build/AppIcon.icns
fi
cp .build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
BINS=""
for arch in $ARCHS; do
  swiftc -O -parse-as-library -target "$arch-apple-macos$MIN" Sources/*.swift -o ".build/HoaxEliminatorForMac-$arch"
  BINS="$BINS .build/HoaxEliminatorForMac-$arch"
done
lipo -create $BINS -output "$APP/Contents/MacOS/HoaxEliminatorForMac"
codesign -s - --force "$APP"
[ "$1" = package ] || { echo "$APP"; exit 0; }

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
NAME="Hoax-Eliminator-for-Mac-$VERSION"
STAGE=".build/package/$NAME"
mkdir -p "$STAGE" ../dist
ditto "$APP" "$STAGE/Hoax Eliminator for Mac.app"
cp Packaging/INSTALL.txt Packaging/THIRD-PARTY-NOTICES.txt "$STAGE/"
ditto -c -k --norsrc --noextattr --keepParent "$STAGE" "../dist/$NAME.zip"
echo "../dist/$NAME.zip"
