#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$project_dir/dist"

swift build --package-path "$project_dir" --configuration release
binary_dir="$(swift build --package-path "$project_dir" --configuration release --show-bin-path)"
staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/daycue-build.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT

app_path="$staging_dir/DayCue.app"
mkdir -p "$app_path/Contents/MacOS"
cp "$binary_dir/DayCue" "$app_path/Contents/MacOS/DayCue"
cp "$project_dir/packaging/Info.plist" "$app_path/Contents/Info.plist"
plutil -lint "$app_path/Contents/Info.plist"
codesign --force --sign - --timestamp=none "$app_path"
codesign --verify --strict "$app_path"

mkdir -p "$output_dir"
rm -rf "$output_dir/DayCue.app"
mv "$app_path" "$output_dir/DayCue.app"
printf 'Built %s\n' "$output_dir/DayCue.app"
