#!/bin/sh
# Renders the notch prompter off screen through slide changes (texts.json: a
# JSON array of scripts) and writes a PNG right after each change (-a) and one
# second later (-b). The two must match: text at the top, fully in view.
#   tests/prompter/run.sh texts.json out-dir
set -e
root=$(cd "$(dirname "$0")/../.." && pwd)
out=$2; mkdir -p "$out"; cp "$1" "$out/texts.json"
tmp=$(mktemp -d)
sed 's/^@main$//' "$root/Textream/Textream/TextreamApp.swift" > "$tmp/TextreamApp.swift"
cd "$root/Textream/Textream"
xcrun swiftc -parse-as-library -default-isolation MainActor -module-cache-path "$tmp/mc" \
  $(ls *.swift | grep -v '^TextreamApp.swift$') "$tmp/TextreamApp.swift" \
  "$root/tests/prompter/SlideChanges.swift" -o "$tmp/slide-changes" 2>&1 | grep -E 'error' || true
"$tmp/slide-changes" "$out"
rm -rf "$tmp"
