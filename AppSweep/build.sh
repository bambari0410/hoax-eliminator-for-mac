#!/bin/sh
# ./build.sh       -> .build/AppSweep.app
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

APP=.build/AppSweep.app
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/"
swiftc -O -parse-as-library Sources/*.swift -o "$APP/Contents/MacOS/AppSweep"
codesign -s - --force "$APP"
echo "$APP"
