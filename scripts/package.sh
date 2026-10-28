#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/dist/DayCue.app/Contents/Info.plist")"
architecture="$(lipo -archs "$project_dir/dist/DayCue.app/Contents/MacOS/DayCue")"
image_path="$project_dir/dist/DayCue-$version-$architecture.dmg"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/daycue-package.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT

ditto "$project_dir/dist/DayCue.app" "$staging_dir/DayCue.app"
ln -s /Applications "$staging_dir/Applications"
hdiutil create \
    -volname DayCue \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -ov \
    "$image_path"
hdiutil verify "$image_path"
printf 'Packaged %s\n' "$image_path"
