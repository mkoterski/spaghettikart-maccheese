#!/bin/zsh
# spmc-build.sh
# SpaghettiKart MacCheese — Intel Mac / macOS Tahoe build script
#
# Clones or updates HarbourMasters/SpaghettiKart, configures cmake with
# Ninja for Intel x86_64, extracts assets from the US ROM (generating
# mk64.o2r and spaghetti.o2r), and compiles the Spaghettify binary.
# The ROM is copied automatically from the central roms/ directory.
#
# Usage:
#   ./spmc-build.sh               # full build (clone → extract → compile)
#   ./spmc-build.sh --skip-deps   # skip Homebrew dep check (faster re-build)
#
# ROM layout (place file here — shared across builds):
#   roms/mk64.us.z64   🇺🇸 Mario Kart 64 US
#                       SHA-1: 579C48E211AE952530FFC8738709F078D5DD215E
#                       (copied to SpaghettiKart/baserom.us.z64 by this script)
#
# Log output:
#   logs/build-<timestamp>.log   ← top-level logs/, survives rm -rf SpaghettiKart/
#
# CHANGELOG
# v0.12 (2026-03-14) - Fix: ROM must be named baserom.us.z64 (not mk64.us.z64) —
#                      upstream Torch expects this exact filename in the repo root;
#                      updated ROM_DEST and all references
# v0.11 (2026-03-14) - Fix: SDL2.framework at /Library/Frameworks/ has broken
#                      sdl2-config.cmake referencing /Library/Headers — added
#                      CMAKE_PREFIX_PATH=$(brew --prefix) and CMAKE_FIND_FRAMEWORK=LAST
#                      to force Homebrew sdl2 over the system framework
# v0.10 (2026-03-14) - Initial version; adapted from pdmv-build-macos.sh v0.16;
#                      cmake+Ninja build; Homebrew deps inline; ROM auto-copy;
#                      ExtractAssets + GenerateO2R targets; Release mode

set -eo pipefail
VERSION="0.12"
SCRIPT_DIR="${0:A:h}"
ROM_SHA1="579C48E211AE952530FFC8738709F078D5DD215E"

# ── Parse arguments ───────────────────────────────────────────────────────────

SKIP_DEPS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-deps) SKIP_DEPS=1; shift ;;
    *) echo "Usage: $0 [--skip-deps]" >&2; exit 1 ;;
  esac
done

REPO_DIR="$SCRIPT_DIR/SpaghettiKart"
BUILD_DIR="$REPO_DIR/build-cmake"
ROM_SOURCE="$SCRIPT_DIR/roms/mk64.us.z64"
TIMESTAMP="$(date '+%Y%m%d-%H%M')"

# Log lives at top-level logs/ — NOT inside SpaghettiKart/ — so it survives
# rm -rf SpaghettiKart/ during stale-clone recovery.
LOG_DIR="$SCRIPT_DIR/logs"
LOGFILE="$LOG_DIR/build-$TIMESTAMP.log"
mkdir -p "$LOG_DIR"

echo "🔨 spmc-build.sh v$VERSION — $(date)" | tee -a "$LOGFILE"
echo "   Log: $LOGFILE" | tee -a "$LOGFILE"

# ── Step 1: Homebrew deps (skippable) ─────────────────────────────────────────

if (( ! SKIP_DEPS )); then
  echo "" | tee -a "$LOGFILE"
  echo "📦 Step 1: Homebrew dependencies" | tee -a "$LOGFILE"
  if ! command -v brew &>/dev/null; then
    echo "   ❌ Homebrew not found. Run ./spmc-initial-setup.sh first." | tee -a "$LOGFILE"
    exit 1
  fi
  BREW_PKGS=(
    cmake ninja git python3
    sdl2 sdl2_net libpng glew
    nlohmann-json libzip tinyxml2
    spdlog boost libogg libvorbis vorbis-tools
  )
  for pkg in "${BREW_PKGS[@]}"; do
    if ! brew list --versions "$pkg" &>/dev/null; then
      echo "   Installing $pkg..." | tee -a "$LOGFILE"
      brew install "$pkg" 2>&1 | tee -a "$LOGFILE"
    else
      echo "   ✅ $(brew list --versions "$pkg")" | tee -a "$LOGFILE"
    fi
  done
else
  echo "" | tee -a "$LOGFILE"
  echo "📦 Step 1: Skipped (--skip-deps)" | tee -a "$LOGFILE"
fi

# ── Step 2: Xcode CLT ─────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔧 Step 2: Xcode CLT" | tee -a "$LOGFILE"
if ! xcode-select -p &>/dev/null; then
  echo "   ❌ Xcode Command Line Tools not found." | tee -a "$LOGFILE"
  echo "      Run: xcode-select --install  then re-run this script." | tee -a "$LOGFILE"
  exit 1
fi
echo "   ✅ $(xcode-select -p)" | tee -a "$LOGFILE"

# ── Step 3: Clone or update ───────────────────────────────────────────────────

# Check for CMakeLists.txt — not just the directory — to detect stale/empty clones.

echo "" | tee -a "$LOGFILE"
echo "📥 Step 3: Clone / update HarbourMasters/SpaghettiKart" | tee -a "$LOGFILE"
if [[ ! -f "$REPO_DIR/CMakeLists.txt" ]]; then
  [[ -d "$REPO_DIR" ]] && echo "   ⚠️  Repo dir exists but CMakeLists.txt missing — removing and re-cloning..." | tee -a "$LOGFILE"
  rm -rf "$REPO_DIR"
  echo "   Cloning..." | tee -a "$LOGFILE"
  git clone --recursive https://github.com/HarbourMasters/SpaghettiKart.git "$REPO_DIR" 2>&1 | tee -a "$LOGFILE"
else
  echo "   Repo exists — pulling latest..." | tee -a "$LOGFILE"
  git -C "$REPO_DIR" pull --recurse-submodules 2>&1 | tee -a "$LOGFILE"
  git -C "$REPO_DIR" submodule update --init --recursive 2>&1 | tee -a "$LOGFILE"
fi

# ── Step 4: ROM ───────────────────────────────────────────────────────────────

# The ExtractAssets cmake target runs Torch from the repo root and expects
# the ROM at SpaghettiKart/baserom.us.z64 — this is the upstream convention.

echo "" | tee -a "$LOGFILE"
echo "🎮 Step 4: ROM" | tee -a "$LOGFILE"

ROM_DEST="$REPO_DIR/baserom.us.z64"
if [[ -f "$ROM_DEST" ]]; then
  echo "   ✅ ROM already in place: $(du -h "$ROM_DEST" | cut -f1)" | tee -a "$LOGFILE"
elif [[ -f "$ROM_SOURCE" ]]; then
  echo "   📋 Copying ROM from roms/ → SpaghettiKart/baserom.us.z64..." | tee -a "$LOGFILE"
  cp "$ROM_SOURCE" "$ROM_DEST"
  echo "   ✅ ROM copied: $(du -h "$ROM_DEST" | cut -f1)" | tee -a "$LOGFILE"
else
  echo "   ⚠️  ROM not found. Place it at either:" | tee -a "$LOGFILE"
  echo "      $ROM_SOURCE  ← recommended (central roms/ dir)" | tee -a "$LOGFILE"
  echo "      $ROM_DEST" | tee -a "$LOGFILE"
  echo "   SHA-1: $ROM_SHA1  (US, .z64 format only)" | tee -a "$LOGFILE"
  echo "   ⚠️  Build will continue but ExtractAssets will fail without ROM." | tee -a "$LOGFILE"
fi

# ── Step 5: CMake configure ───────────────────────────────────────────────────

# CMAKE_OSX_ARCHITECTURES=x86_64 ensures an Intel binary even under Rosetta.
# Ninja generator for maximum performance (per upstream BUILDING.md).
# Release mode for packaging.
#
# CMAKE_PREFIX_PATH: force Homebrew sdl2 over /Library/Frameworks/SDL2.framework.
# The framework's bundled sdl2-config.cmake references /Library/Headers which
# doesn't exist on modern macOS, causing a cmake error in libultraship.
# CMAKE_FIND_FRAMEWORK=LAST ensures cmake prefers Homebrew pkg-config/cmake
# packages over any system-wide .framework bundles.

BREW_PREFIX="$(brew --prefix)"

echo "" | tee -a "$LOGFILE"
echo "⚙️  Step 5: CMake configure (Ninja, x86_64, Release)" | tee -a "$LOGFILE"
echo "   Homebrew prefix: $BREW_PREFIX" | tee -a "$LOGFILE"
cmake -H"$REPO_DIR" \
  -B"$BUILD_DIR" \
  -GNinja \
  -DCMAKE_BUILD_TYPE:STRING=Release \
  -DCMAKE_OSX_ARCHITECTURES=x86_64 \
  -DCMAKE_PREFIX_PATH="$BREW_PREFIX" \
  -DCMAKE_FIND_FRAMEWORK=LAST \
  -DNON_PORTABLE=OFF \
  2>&1 | tee -a "$LOGFILE"

# ── Step 6: Extract assets ────────────────────────────────────────────────────

# ExtractAssets generates mk64.o2r (from ROM) and spaghetti.o2r (from yamls/).
# If the ROM isn't found the target will fail — that's expected and the error
# message from upstream is clear enough.

echo "" | tee -a "$LOGFILE"
echo "📦 Step 6: Extract assets (mk64.o2r + spaghetti.o2r)" | tee -a "$LOGFILE"

# Check if o2r files already exist — skip extraction if so
if [[ -f "$BUILD_DIR/mk64.o2r" && -f "$BUILD_DIR/spaghetti.o2r" ]]; then
  echo "   ✅ mk64.o2r already exists: $(du -h "$BUILD_DIR/mk64.o2r" | cut -f1)" | tee -a "$LOGFILE"
  echo "   ✅ spaghetti.o2r already exists: $(du -h "$BUILD_DIR/spaghetti.o2r" | cut -f1)" | tee -a "$LOGFILE"
  echo "   (Delete these files and re-run to force re-extraction)" | tee -a "$LOGFILE"
else
  cmake --build "$BUILD_DIR" --target ExtractAssets 2>&1 | tee -a "$LOGFILE"
  if [[ -f "$BUILD_DIR/mk64.o2r" ]]; then
    echo "   ✅ mk64.o2r: $(du -h "$BUILD_DIR/mk64.o2r" | cut -f1)" | tee -a "$LOGFILE"
  else
    # o2r may be generated in the repo root by some versions
    for o2r in "$REPO_DIR"/mk64.o2r "$REPO_DIR"/build-cmake/mk64.o2r; do
      [[ -f "$o2r" ]] && echo "   ✅ mk64.o2r found at: $o2r" | tee -a "$LOGFILE" && break
    done
  fi
fi

# ── Step 7: Build ─────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔨 Step 7: Build ($(sysctl -n hw.logicalcpu) cores)" | tee -a "$LOGFILE"
cmake --build "$BUILD_DIR" --config Release -j"$(sysctl -n hw.logicalcpu)" 2>&1 | tee -a "$LOGFILE"

# ── Step 8: Binary validation ─────────────────────────────────────────────────

# The built binary is named Spaghettify on macOS.

echo "" | tee -a "$LOGFILE"
echo "🔍 Step 8: Validate binary" | tee -a "$LOGFILE"

BINARY=""
for candidate in "$BUILD_DIR/Spaghettify" "$BUILD_DIR/spaghettify" \
                  "$BUILD_DIR/Spaghettify.app/Contents/MacOS/Spaghettify"; do
  if [[ -f "$candidate" ]]; then
    BINARY="$candidate"
    break
  fi
done

if [[ -z "$BINARY" ]]; then
  echo "   ❌ Binary not found in build-cmake/" | tee -a "$LOGFILE"
  echo "   Build dir contents:" | tee -a "$LOGFILE"
  ls -lh "$BUILD_DIR" 2>/dev/null | head -20 | tee -a "$LOGFILE"
  echo "   Check log: $LOGFILE" | tee -a "$LOGFILE"
  exit 1
fi
chmod +x "$BINARY"
echo "   ✅ Binary: $(file "$BINARY" | grep -o 'Mach-O.*')" | tee -a "$LOGFILE"
echo "   ✅ Size:   $(du -h "$BINARY" | cut -f1)" | tee -a "$LOGFILE"
echo "   ✅ Built:  $(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$BINARY")" | tee -a "$LOGFILE"

# ── Summary ───────────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"
echo "✅ spmc-build.sh v$VERSION complete!" | tee -a "$LOGFILE"
echo "   📍 $BINARY" | tee -a "$LOGFILE"
echo "   📄 $LOGFILE" | tee -a "$LOGFILE"
echo "   👉 ./run-spmc-macos.sh" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"