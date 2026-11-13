#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h:h}"
lab_dir="$project_root/build/glow-study"
app_dir="$lab_dir/Cove Glow Lab.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$project_root/prototypes/loading-light/dia-address-crop.png" "$lab_dir/dia-address-crop.png"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
    -parse-as-library "$project_root/prototypes/loading-light/GlowLab.swift" \
    -o "$app_dir/Contents/MacOS/CoveGlowLab"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CoveGlowLab</string>
<key>CFBundleIdentifier</key><string>local.cove.glow-lab</string>
<key>CFBundleName</key><string>Cove Glow Lab</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
printf '%s\n' "$app_dir"
