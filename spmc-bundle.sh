#!/bin/zsh
# spmc-bundle.sh
# SpaghettiKart MacCheese — Intel Mac / macOS Tahoe app bundle creator
#
# Wraps the compiled Spaghettify binary into a proper
# "SpaghettiKart MacCheese.app" bundle. The binary is placed in
# Contents/MacOS/ behind a zsh wrapper that sets cwd to
# Contents/Resources/ so spaghettify.cfg.json, mk64.o2r, spaghetti.o2r,
# and the mods/ directory are found at runtime.
#
# Usage:
#   ./spmc-bundle.sh
#
# CHANGELOG
# v0.10 (2026-03-14) - Initial version; adapted from pdmv-bundle-macos.sh v0.10;
#                      cwd wrapper for o2r resolution; placeholder .icns;
#                      mods/ directory support

set -eo pipefail
VERSION="0.10"
SCRIPT_DIR="${0:A:h}"

REPO_DIR="$SCRIPT_DIR/SpaghettiKart"
BUILD_DIR="$REPO_DIR/build-cmake"
APP_NAME="SpaghettiKart MacCheese"
BUNDLE="$BUILD_DIR/$APP_NAME.app"
ICNS="$BUILD_DIR/spaghettikart.icns"
TIMESTAMP="$(date '+%Y%m%d-%H%M')"

LOG_DIR="$SCRIPT_DIR/logs"
LOGFILE="$LOG_DIR/bundle-$TIMESTAMP.log"
mkdir -p "$LOG_DIR"

echo "🎁 spmc-bundle.sh v$VERSION — $(date)" | tee -a "$LOGFILE"

# ── Locate binary ─────────────────────────────────────────────────────────────

BINARY=""
for candidate in "$BUILD_DIR/Spaghettify" "$BUILD_DIR/spaghettify"; do
  if [[ -f "$candidate" ]]; then
    BINARY="$candidate"
    break
  fi
done

# ── Preflight checks ──────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔍 Preflight checks" | tee -a "$LOGFILE"

if [[ -z "$BINARY" ]]; then
  echo "   ❌ Binary not found — run ./spmc-build.sh first" | tee -a "$LOGFILE"
  exit 1
fi

O2R_FOUND=0
for o2r in "$BUILD_DIR/mk64.o2r" "$REPO_DIR/mk64.o2r"; do
  if [[ -f "$o2r" ]]; then
    MK64_O2R="$o2r"
    O2R_FOUND=1
    break
  fi
done
if (( ! O2R_FOUND )); then
  echo "   ❌ mk64.o2r not found — run ./spmc-build.sh first (needs ROM)" | tee -a "$LOGFILE"
  exit 1
fi

SPAGHETTI_O2R=""
for o2r in "$BUILD_DIR/spaghetti.o2r" "$REPO_DIR/spaghetti.o2r"; do
  [[ -f "$o2r" ]] && SPAGHETTI_O2R="$o2r" && break
done
if [[ -z "$SPAGHETTI_O2R" ]]; then
  echo "   ❌ spaghetti.o2r not found — run ./spmc-build.sh first" | tee -a "$LOGFILE"
  exit 1
fi

echo "   ✅ Binary: ${BINARY:t}" | tee -a "$LOGFILE"
echo "   ✅ mk64.o2r: $(du -h "$MK64_O2R" | cut -f1)" | tee -a "$LOGFILE"
echo "   ✅ spaghetti.o2r: $(du -h "$SPAGHETTI_O2R" | cut -f1)" | tee -a "$LOGFILE"

# ── Step 1: Generate placeholder .icns ────────────────────────────────────────

# Replace with a real SpaghettiKart iconset (icon.png from upstream repo) when
# artwork is available. Until then a tomato-red placeholder is generated.

if [[ -f "$REPO_DIR/icon.png" ]]; then
  echo "" | tee -a "$LOGFILE"
  echo "🖼  Step 1: Generate .icns from upstream icon.png" | tee -a "$LOGFILE"
  ICONSET_DIR="$(mktemp -d)/sk.iconset"
  mkdir -p "$ICONSET_DIR"
  for SIZE in 16 32 64 128 256 512; do
    sips -z $SIZE $SIZE "$REPO_DIR/icon.png" \
      --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" &>/dev/null
    if (( SIZE >= 32 )); then
      HALF=$(( SIZE / 2 ))
      cp "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png" \
         "$ICONSET_DIR/icon_${HALF}x${HALF}@2x.png"
    fi
  done
  iconutil -c icns "$ICONSET_DIR" -o "$ICNS" 2>&1 | tee -a "$LOGFILE"
  rm -rf "$(dirname "$ICONSET_DIR")"
elif [[ ! -f "$ICNS" ]]; then
  echo "" | tee -a "$LOGFILE"
  echo "🖼  Step 1: Generating placeholder spaghettikart.icns..." | tee -a "$LOGFILE"
  ICONSET_TMP="$(mktemp -d)/sk.iconset"
  mkdir -p "$ICONSET_TMP"
  python3 - "$ICONSET_TMP" << 'PYEOF'
import struct, zlib, sys, os
def mkpng(w, h):
    rows = bytearray()
    for y in range(h):
        rows += b'\x00'
        for x in range(w):
            rows += bytes([180, 30, 20, 255])  # tomato red — spaghetti sauce!
    compressed = zlib.compress(bytes(rows), 9)
    def chunk(name, data):
        c = zlib.crc32(name + data) & 0xffffffff
        return struct.pack('>I', len(data)) + name + data + struct.pack('>I', c)
    return (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) +
            chunk(b'IDAT', compressed) +
            chunk(b'IEND', b''))
iconset = sys.argv[1]
for s in [16, 32, 64, 128, 256, 512]:
    with open(f'{iconset}/icon_{s}x{s}.png', 'wb') as f:     f.write(mkpng(s, s))
    with open(f'{iconset}/icon_{s}x{s}@2x.png', 'wb') as f:  f.write(mkpng(s*2, s*2))
PYEOF
  iconutil -c icns "$ICONSET_TMP" -o "$ICNS" 2>&1 | tee -a "$LOGFILE"
  rm -rf "$(dirname "$ICONSET_TMP")"
fi
echo "   ✅ spaghettikart.icns ($(du -h "$ICNS" | cut -f1))" | tee -a "$LOGFILE"

# ── Step 2: Bundle structure ──────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📁 Step 2: Creating bundle structure..." | tee -a "$LOGFILE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources/mods"
echo "   ✅ $BUNDLE created" | tee -a "$LOGFILE"

# ── Step 3: Binary + cwd wrapper ──────────────────────────────────────────────

# The wrapper sets cwd to Contents/Resources/ so spaghettify.cfg.json,
# mk64.o2r, spaghetti.o2r, and mods/ are found at runtime.

echo "" | tee -a "$LOGFILE"
echo "📦 Step 3: Binary + wrapper..." | tee -a "$LOGFILE"
cp "$BINARY" "$BUNDLE/Contents/MacOS/SpaghettifyBin"
chmod +x "$BUNDLE/Contents/MacOS/SpaghettifyBin"

cat > "$BUNDLE/Contents/MacOS/Spaghettify" << 'WRAPPER'
#!/bin/zsh
export DYLD_LIBRARY_PATH="/usr/local/lib:${DYLD_LIBRARY_PATH:-}"
cd "${0:A:h}/../Resources"
exec "${0:A:h}/SpaghettifyBin" "$@"
WRAPPER
chmod +x "$BUNDLE/Contents/MacOS/Spaghettify"
echo "   ✅ Launcher wrapper created (cwd → Resources/)" | tee -a "$LOGFILE"

# ── Step 4: Icon ──────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🖼  Step 4: Icon..." | tee -a "$LOGFILE"
cp "$ICNS" "$BUNDLE/Contents/Resources/spaghettikart.icns"
echo "   ✅ spaghettikart.icns → Resources/" | tee -a "$LOGFILE"

# ── Step 5: Game assets ───────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📦 Step 5: Game assets (o2r files + mods/)..." | tee -a "$LOGFILE"
cp "$MK64_O2R" "$BUNDLE/Contents/Resources/mk64.o2r"
echo "   ✅ mk64.o2r ($(du -h "$BUNDLE/Contents/Resources/mk64.o2r" | cut -f1))" | tee -a "$LOGFILE"

cp "$SPAGHETTI_O2R" "$BUNDLE/Contents/Resources/spaghetti.o2r"
echo "   ✅ spaghetti.o2r ($(du -h "$BUNDLE/Contents/Resources/spaghetti.o2r" | cut -f1))" | tee -a "$LOGFILE"

# Copy existing config if present
[[ -f "$BUILD_DIR/spaghettify.cfg.json" ]] && \
  cp "$BUILD_DIR/spaghettify.cfg.json" "$BUNDLE/Contents/Resources/spaghettify.cfg.json" && \
  echo "   ✅ spaghettify.cfg.json" | tee -a "$LOGFILE" || true

# Copy mods if any exist
if compgen -G "$BUILD_DIR/mods/*" &>/dev/null 2>&1 || [[ -d "$BUILD_DIR/mods" && "$(ls -A "$BUILD_DIR/mods" 2>/dev/null)" ]]; then
  cp -R "$BUILD_DIR"/mods/* "$BUNDLE/Contents/Resources/mods/" 2>/dev/null || true
  echo "   ✅ mods/ ($(du -sh "$BUNDLE/Contents/Resources/mods" | cut -f1))" | tee -a "$LOGFILE"
else
  echo "   · mods/ (empty — place .o2r or .zip mods here)" | tee -a "$LOGFILE"
fi

# ── Step 6: Info.plist ────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "📄 Step 6: Info.plist..." | tee -a "$LOGFILE"
cat > "$BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>              <string>SpaghettiKart MacCheese</string>
  <key>CFBundleDisplayName</key>       <string>SpaghettiKart MacCheese</string>
  <key>CFBundleIdentifier</key>        <string>com.mkoterski.spaghettikart-maccheese</string>
  <key>CFBundleVersion</key>           <string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key>        <string>Spaghettify</string>
  <key>CFBundleIconFile</key>          <string>spaghettikart</string>
  <key>CFBundlePackageType</key>       <string>APPL</string>
  <key>LSMinimumSystemVersion</key>    <string>10.9</string>
  <key>NSHighResolutionCapable</key>   <true/>
  <key>NSHumanReadableCopyright</key>  <string>mkoterski / HarbourMasters</string>
</dict>
</plist>
PLIST
echo "   ✅ Info.plist written (LSMinimumSystemVersion 10.9)" | tee -a "$LOGFILE"

# ── Step 7: Verify bundle ─────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔍 Step 7: Verify bundle..." | tee -a "$LOGFILE"
echo "   Binary:  $(file "$BUNDLE/Contents/MacOS/SpaghettifyBin" | grep -o 'Mach-O.*')" | tee -a "$LOGFILE"
echo "   Icon:    $(du -h "$BUNDLE/Contents/Resources/spaghettikart.icns" | cut -f1)" | tee -a "$LOGFILE"
echo "   mk64:    $(du -h "$BUNDLE/Contents/Resources/mk64.o2r" | cut -f1)" | tee -a "$LOGFILE"
echo "   Bundle:  $(du -sh "$BUNDLE" | cut -f1) total" | tee -a "$LOGFILE"

echo "" | tee -a "$LOGFILE"
echo "✅ spmc-bundle.sh v$VERSION complete!" | tee -a "$LOGFILE"
echo "   📍 $BUNDLE" | tee -a "$LOGFILE"
echo "   👉 Test by double-clicking, then run ./spmc-package.sh" | tee -a "$LOGFILE"