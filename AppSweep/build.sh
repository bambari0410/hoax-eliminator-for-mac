#!/bin/sh
# ./build.sh       -> ".build/Hoax Eliminator for Mac.app"
# ./build.sh test  -> run the matching self-check (fake filesystem, nothing real is touched)
# ./build.sh test --e2e | --plant | --verify | --clean  -> real ~/Library test with a dummy app, see Tests/E2E.swift
set -e
cd "$(dirname "$0")"
mkdir -p .build

if [ "$1" = test ]; then
  shift
  swiftc Sources/Cleaner.swift Sources/Security.swift Sources/Privileged.swift Tests/*.swift -o .build/check
  exec .build/check "$@"
fi

APP=".build/Hoax Eliminator for Mac.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/"
# Icon is drawn by Tools/icon.swift; redrawn only when the script changes.
if [ Tools/icon.swift -nt .build/AppIcon.icns ]; then
  swift Tools/icon.swift .build/AppIcon.iconset && iconutil -c icns .build/AppIcon.iconset -o .build/AppIcon.icns
fi
cp .build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
swiftc -O -parse-as-library Sources/*.swift -o "$APP/Contents/MacOS/HoaxEliminatorForMac"
codesign -s - --force "$APP"
echo "$APP"
