#!/bin/sh
# Installs the latest Hoax Eliminator for Mac and opens it:
#   curl -fsSL https://bambari0410.github.io/hoax-eliminator-for-mac/install.sh | sh
# curl does not tag downloads with com.apple.quarantine, so the unnotarized app opens without the "열 수 없음" warning.
# HOAX_DEST=<folder> installs somewhere else; without write access to /Applications it goes to ~/Applications.
set -eu
repo=bambari0410/hoax-eliminator-for-mac
name="Hoax Eliminator for Mac.app"
dest=${HOAX_DEST:-/Applications}
[ -w "$dest" ] || { dest="$HOME/Applications"; mkdir -p "$dest"; }

echo "최신 버전을 찾는 중이에요…"
url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -n 1 | cut -d '"' -f 4)
[ -n "$url" ] || { echo "최신 버전을 찾지 못했어요. https://github.com/$repo/releases 에서 직접 받아 주세요." >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "받는 중이에요: $url"
curl -fsSL "$url" -o "$tmp/app.zip"
ditto -x -k "$tmp/app.zip" "$tmp/x"
app=$(find "$tmp/x" -maxdepth 2 -type d -name "$name" | head -n 1)
[ -n "$app" ] || { echo "받은 zip에서 앱을 찾지 못했어요." >&2; exit 1; }

# Replace an older copy; quit it first if it is running.
pkill -x HoaxEliminatorForMac 2>/dev/null || true
rm -rf "${dest:?}/$name"
ditto "$app" "$dest/$name"
xattr -dr com.apple.quarantine "$dest/$name" 2>/dev/null || true
echo "설치했어요: $dest/$name"
open "$dest/$name"
