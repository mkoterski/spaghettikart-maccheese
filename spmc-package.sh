#!/bin/zsh
# spmc-package.sh
# SpaghettiKart MacCheese — Intel Mac / macOS Tahoe DMG packager
#
# Creates a distributable DMG installer from "SpaghettiKart MacCheese.app".
# Run spmc-bundle.sh first to produce the .app bundle.
#
# Usage:
#   ./spmc-package.sh
#
# Output:
#   dist/SpaghettiKart-MacCheese-Intel-Mac.dmg
#   logs/package-<timestamp>.log
#
# DMG layout:
#   SpaghettiKart MacCheese.app  ← drag to Applications
#   Applications/                ← symlink
#   .background/background.png   ← tomato-red/black spaghetti themed background
#
# CHANGELOG
# v0.10 (2026-03-14) - Initial version; adapted from pdmv-package-macos.sh v0.11;
#                      tomato-red/black DMG background; icon from upstream or
#                      placeholder; battle-tested plist mount-point parse;
#                      Finder eject before hdiutil detach; NSWorkspace icon applier

set -eo pipefail
VERSION="0.10"
SCRIPT_DIR="${0:A:h}"

REPO_DIR="$SCRIPT_DIR/SpaghettiKart"
BUILD_DIR="$REPO_DIR/build-cmake"
APP_NAME="SpaghettiKart MacCheese"
BUNDLE_DIR="$BUILD_DIR/$APP_NAME.app"
DIST_DIR="$SCRIPT_DIR/dist"
DMG_NAME="SpaghettiKart-MacCheese-Intel-Mac"
DMG_FINAL="$DIST_DIR/${DMG_NAME}.dmg"
DMG_STAGING="$DIST_DIR/${DMG_NAME}-staging"
DMG_TMP="$DIST_DIR/${DMG_NAME}-tmp.dmg"
DMG_VOLUME="SpaghettiKart-MacCheese"
DMG_SIZE="200m"
ICON_SRC="$REPO_DIR/icon.png"
TIMESTAMP="$(date '+%Y%m%d-%H%M')"

LOG_DIR="$SCRIPT_DIR/logs"
LOGFILE="$LOG_DIR/package-$TIMESTAMP.log"
mkdir -p "$LOG_DIR" "$DIST_DIR"

echo "📀 spmc-package.sh v$VERSION — $(date)" | tee -a "$LOGFILE"
echo "   Bundle:  $BUNDLE_DIR" | tee -a "$LOGFILE"
echo "   Output:  $DMG_FINAL" | tee -a "$LOGFILE"
echo "   Log:     $LOGFILE" | tee -a "$LOGFILE"

# ── Preflight: eject any stale mounts ─────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔍 Checking for stale mounts..." | tee -a "$LOGFILE"
for vol in /Volumes/SpaghettiKart*(N); do
  echo "   ⚠️  Ejecting stale mount: $vol" | tee -a "$LOGFILE"
  hdiutil detach "$vol" -force 2>&1 | tee -a "$LOGFILE" || true
done

# ── Preflight checks ──────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔍 Preflight checks..." | tee -a "$LOGFILE"

if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "   ❌ Bundle not found: $BUNDLE_DIR" | tee -a "$LOGFILE"
  echo "      Run: ./spmc-bundle.sh" | tee -a "$LOGFILE"
  exit 1
fi

if [[ ! -f "$BUNDLE_DIR/Contents/MacOS/SpaghettifyBin" ]]; then
  echo "   ❌ Bundle appears incomplete (missing SpaghettifyBin)" | tee -a "$LOGFILE"
  echo "      Run: ./spmc-bundle.sh" | tee -a "$LOGFILE"
  exit 1
fi

echo "   ✅ Bundle: $(du -sh "$BUNDLE_DIR" | cut -f1)" | tee -a "$LOGFILE"

rm -rf "$DMG_STAGING" "$DMG_TMP" "$DMG_FINAL"
mkdir -p "$DMG_STAGING/.background"

# ── Step 1: Generate .icns ────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🖼  Step 1: Generate .icns" | tee -a "$LOGFILE"

ICNS_PATH="$DIST_DIR/spaghettikart.icns"
ICONSET_DIR="$DIST_DIR/spaghettikart.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

if [[ -f "$ICON_SRC" ]]; then
  echo "   Using upstream icon.png" | tee -a "$LOGFILE"
  for SIZE in 16 32 64 128 256 512 1024; do
    sips -z $SIZE $SIZE "$ICON_SRC" \
      --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" &>/dev/null
    if (( SIZE >= 32 )); then
      HALF=$(( SIZE / 2 ))
      cp "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" \
         "$ICONSET_DIR/icon_${HALF}x${HALF}@2x.png"
    fi
  done
else
  echo "   ⚠️  icon.png not found — using placeholder" | tee -a "$LOGFILE"
  # Fall back to the .icns already in the bundle
  if [[ -f "$BUNDLE_DIR/Contents/Resources/spaghettikart.icns" ]]; then
    cp "$BUNDLE_DIR/Contents/Resources/spaghettikart.icns" "$ICNS_PATH"
    rm -rf "$ICONSET_DIR"
    echo "   ✅ .icns from bundle: $(du -h "$ICNS_PATH" | cut -f1)" | tee -a "$LOGFILE"
  fi
fi

if [[ -d "$ICONSET_DIR" && "$(ls -A "$ICONSET_DIR" 2>/dev/null)" ]]; then
  iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH" 2>&1 | tee -a "$LOGFILE"
  rm -rf "$ICONSET_DIR"
  echo "   ✅ .icns generated: $(du -h "$ICNS_PATH" | cut -f1)" | tee -a "$LOGFILE"
fi

# ── Step 2: Generate DMG background ──────────────────────────────────────────

# Tomato-red/black background — spaghetti sauce meets racing asphalt.

echo "" | tee -a "$LOGFILE"
echo "🍝 Step 2: Generate DMG background (tomato-red/black theme)" | tee -a "$LOGFILE"

BG_PATH="$DMG_STAGING/.background/background.png"

python3 - "$BG_PATH" << 'PYEOF' 2>&1 | tee -a "$LOGFILE"
import struct, zlib, sys, math

W, H = 660, 400
out = sys.argv[1]

def png_chunk(name, data):
    c = zlib.crc32(name + data) & 0xffffffff
    return struct.pack('>I', len(data)) + name + data + struct.pack('>I', c)

rows = []
for y in range(H):
    row = []
    for x in range(W):
        nx = x / W
        ny = y / H

        # Near-black base — racing asphalt
        r_base, g_base, b_base = 8, 4, 4

        # Tomato-red glow bottom-left — spaghetti sauce!
        dx1 = nx - 0.10; dy1 = ny - 0.90
        red1 = max(0.0, 1.0 - (dx1*dx1 + dy1*dy1) / 0.35) * 120

        # Secondary warm accent top-right — cheese gold
        dx2 = nx - 0.88; dy2 = ny - 0.08
        gold2 = max(0.0, 1.0 - (dx2*dx2 + dy2*dy2) / 0.18) * 55

        # Subtle horizontal scanlines
        scanline = (math.sin(ny * H * 1.8) * 0.5 + 0.5) * 3.0

        # Label readability band
        dy_label = (ny - 0.68) / 0.07
        label_lift = math.exp(-dy_label * dy_label * 0.5) * 16

        # Edge vignette
        edge_x = min(nx, 1.0 - nx) * 2.0
        edge_y = min(ny, 1.0 - ny) * 2.0
        vignette = (1.0 - edge_x * edge_y) * 20

        r = max(0, min(255, int(r_base + red1*0.92 + gold2*0.85 + scanline + label_lift*0.5 - vignette)))
        g = max(0, min(255, int(g_base + red1*0.12 + gold2*0.60 + scanline*0.3 + label_lift*0.4 - vignette*0.8)))
        b = max(0, min(255, int(b_base + red1*0.04 + gold2*0.08 + scanline*0.3 + label_lift*0.35 - vignette*0.7)))

        row += [r, g, b]
    rows.append(bytes(row))

raw = b''.join(b'\x00' + r for r in rows)
compressed = zlib.compress(raw, 9)

with open(out, 'wb') as f:
    f.write(b'\x89PNG\r\n\x1a\n')
    f.write(png_chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0)))
    f.write(png_chunk(b'IDAT', compressed))
    f.write(png_chunk(b'IEND', b''))

import os
print(f"background.png written ({os.path.getsize(out)} bytes)")
PYEOF

echo "   ✅ Background: $(du -h "$BG_PATH" | cut -f1)" | tee -a "$LOGFILE"

# ── Step 3: Populate staging folder ──────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📁 Step 3: Staging DMG contents" | tee -a "$LOGFILE"
cp -R "$BUNDLE_DIR" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"
echo "   ✅ $APP_NAME.app + /Applications alias staged" | tee -a "$LOGFILE"

# ── Step 4: Create writable DMG ──────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "💿 Step 4: Create writable DMG" | tee -a "$LOGFILE"
hdiutil create \
  -srcfolder "$DMG_STAGING" \
  -volname   "$DMG_VOLUME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,b=16" \
  -format UDRW \
  -size "$DMG_SIZE" \
  "$DMG_TMP" 2>&1 | tee -a "$LOGFILE"
echo "   ✅ Writable DMG created" | tee -a "$LOGFILE"

# ── Step 5: Mount DMG — extract mount point via plist ─────────────────────────

echo "" | tee -a "$LOGFILE"
echo "💿 Step 5: Mount DMG" | tee -a "$LOGFILE"

ATTACH_PLIST="$LOG_DIR/attach-$$.plist"
hdiutil attach -readwrite -noverify -noautoopen -plist "$DMG_TMP" \
  > "$ATTACH_PLIST" 2>&1

ATTACH_RESULT="$(python3 - "$ATTACH_PLIST" << 'PYEOF'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    data = plistlib.load(f)
for entity in data.get('system-entities', []):
    mp = entity.get('mount-point', '')
    de = entity.get('dev-entry', '')
    if mp:
        print(f"{mp}|{de}")
        break
PYEOF
)"

rm -f "$ATTACH_PLIST"

MOUNT_DIR="$(echo "$ATTACH_RESULT" | cut -d'|' -f1)"
DEV_ENTRY="$(echo "$ATTACH_RESULT" | cut -d'|' -f2)"

if [[ -z "$MOUNT_DIR" ]]; then
  echo "   ❌ Failed to get mount point from hdiutil attach plist" | tee -a "$LOGFILE"
  exit 1
fi

echo "   ✅ Mounted at: '$MOUNT_DIR'  (dev: $DEV_ENTRY)" | tee -a "$LOGFILE"
sleep 2

# ── Step 6: Style with osascript ─────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🎨 Step 6: Style DMG window (tomato-red/black theme)" | tee -a "$LOGFILE"

ACTUAL_VOLUME="${MOUNT_DIR##*/Volumes/}"
echo "   Volume name: '$ACTUAL_VOLUME'" | tee -a "$LOGFILE"

SetFile -a V "$MOUNT_DIR/.background" 2>&1 | tee -a "$LOGFILE" || \
chflags hidden "$MOUNT_DIR/.background" 2>&1 | tee -a "$LOGFILE" || \
echo "   ⚠️  Could not hide .background (non-fatal)" | tee -a "$LOGFILE"

osascript - "$ACTUAL_VOLUME" << 'OSASCRIPT' 2>&1 | tee -a "$LOGFILE"
on run argv
    set volName to item 1 of argv
    tell application "Finder"
        tell disk volName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {400, 100, 1060, 500}
            set theViewOptions to the icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 100
            set text size of theViewOptions to 13
            set background picture of theViewOptions to ¬
                file ".background:background.png"
            set position of item 1 of container window to {160, 180}
            set position of item 2 of container window to {500, 180}
            update without registering applications
            delay 3
            close
        end tell
    end tell
end run
OSASCRIPT

echo "   ✅ DMG styled" | tee -a "$LOGFILE"

# ── Step 7: Release Finder's hold, then detach ───────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "💿 Step 7: Unmount DMG" | tee -a "$LOGFILE"

sync
sleep 5

osascript - "$ACTUAL_VOLUME" << 'EJECTSCRIPT' 2>&1 | tee -a "$LOGFILE" || true
on run argv
    set volName to item 1 of argv
    tell application "Finder"
        try
            eject disk volName
        end try
    end tell
end run
EJECTSCRIPT

sleep 2

if [[ -d "$MOUNT_DIR" ]]; then
  hdiutil detach "$MOUNT_DIR" -force 2>&1 | tee -a "$LOGFILE" || \
  hdiutil detach "$DEV_ENTRY" -force 2>&1 | tee -a "$LOGFILE"
else
  echo "   (volume already unmounted by Finder eject)" | tee -a "$LOGFILE"
fi

echo "   ✅ DMG unmounted" | tee -a "$LOGFILE"

# ── Step 8: Convert to compressed read-only DMG ──────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🗜  Step 8: Convert to compressed read-only DMG" | tee -a "$LOGFILE"
hdiutil convert "$DMG_TMP" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_FINAL" 2>&1 | tee -a "$LOGFILE"

rm -f "$DMG_TMP"
rm -rf "$DMG_STAGING"
echo "   ✅ Compressed DMG created" | tee -a "$LOGFILE"

# ── Step 9: Verify DMG ───────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔍 Step 9: Verify DMG" | tee -a "$LOGFILE"
hdiutil verify "$DMG_FINAL" 2>&1 | tee -a "$LOGFILE"
echo "   ✅ Size: $(du -h "$DMG_FINAL" | cut -f1)" | tee -a "$LOGFILE"

# ── Step 10: Apply app icon to DMG file ──────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🎨 Step 10: Apply app icon to DMG file" | tee -a "$LOGFILE"

osascript - "$BUNDLE_DIR" "$DMG_FINAL" << 'ICONSCRIPT' 2>&1 | tee -a "$LOGFILE"
use framework "AppKit"
use framework "Foundation"
use scripting additions

on run argv
    set appPath to item 1 of argv
    set dmgPath to item 2 of argv
    try
        set ws to current application's NSWorkspace's sharedWorkspace()
        set appIcon to ws's iconForFile:appPath
        set didSet to ws's setIcon:appIcon forFile:dmgPath options:0
        if didSet as boolean then
            log "✅ SpaghettiKart icon applied to DMG"
        else
            log "⚠️  setIcon returned false (icon may not persist)"
        end if
    on error errMsg number errNum
        log "⚠️  Icon not applied (non-fatal): " & errMsg & " (" & errNum & ")"
    end try
end run
ICONSCRIPT

# ── Summary ───────────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"
echo "✅ spmc-package.sh v$VERSION complete!" | tee -a "$LOGFILE"
echo "   📀 $DMG_FINAL" | tee -a "$LOGFILE"
echo "   📄 $LOGFILE" | tee -a "$LOGFILE"
echo "   👉 Distribute or drag-mount to install $APP_NAME" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"