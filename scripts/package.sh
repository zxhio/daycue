#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$project_dir/dist/DayCue.app/Contents/Info.plist")"
architecture="$(lipo -archs "$project_dir/dist/DayCue.app/Contents/MacOS/DayCue")"
image_path="$project_dir/dist/DayCue-$version-$architecture.dmg"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/daycue-package.XXXXXX")"
mounted_volume=""
cleanup() {
    if [[ -n "$mounted_volume" ]]; then
        hdiutil detach "$mounted_volume" >/dev/null || true
    fi
    rm -rf "$staging_dir"
}
trap cleanup EXIT

volume_dir="$staging_dir/volume"
mount_dir="$staging_dir/mount"
mkdir -p "$volume_dir" "$mount_dir"
ditto "$project_dir/dist/DayCue.app" "$volume_dir/DayCue.app"
ln -s /Applications "$volume_dir/Applications"
cp "$project_dir/dist/DayCue.app/Contents/Resources/DayCue.icns" "$volume_dir/.VolumeIcon.icns"
hdiutil create \
    -volname DayCue \
    -srcfolder "$volume_dir" \
    -format UDRW \
    "$staging_dir/DayCue.dmg"
hdiutil attach -nobrowse -mountpoint "$mount_dir" "$staging_dir/DayCue.dmg"
mounted_volume="$mount_dir"
xcrun SetFile -a C "$mount_dir"
hdiutil detach "$mount_dir"
mounted_volume=""
hdiutil convert "$staging_dir/DayCue.dmg" -format UDZO -ov -o "$image_path"
hdiutil verify "$image_path"
xcrun swift - "$project_dir/dist/DayCue.app/Contents/Resources/DayCue.icns" "$image_path" <<'SWIFT'
import AppKit

let arguments = CommandLine.arguments
guard let icon = NSImage(contentsOfFile: arguments[1]),
      NSWorkspace.shared.setIcon(icon, forFile: arguments[2], options: []) else {
    fputs("Could not set disk image icon.\n", stderr)
    exit(1)
}
SWIFT
printf 'Packaged %s\n' "$image_path"
