#!/bin/zsh
# spmc-initial-setup.sh
# SpaghettiKart MacCheese — first-run setup for macOS Tahoe / Intel Mac
#
# Installs Xcode CLT, Homebrew, build dependencies (cmake, ninja, python3,
# sdl2, libpng, glew, nlohmann-json, libzip, vorbis-tools, sdl2_net,
# tinyxml2, spdlog, boost, libogg, libvorbis).
# Validates any ROM already present in the central roms/ directory.
# Safe to re-run: all steps are idempotent.
#
# Usage:
#   ./spmc-initial-setup.sh
#
# Output:
#   spaghettikart-maccheese/logs/initial-setup-<timestamp>.log
#
# ROM layout (place file here before building):
#   roms/mk64.us.z64   🇺🇸 Mario Kart 64 US  (SHA-1: 579C48E211AE952530FFC8738709F078D5DD215E)
#
# CHANGELOG
# v0.10 (2026-03-14) - Initial version; adapted from pdmv-initial-setup.sh v0.13

set -eo pipefail
VERSION="0.10"
SCRIPT_DIR="${0:A:h}"
TIMESTAMP="$(date '+%Y%m%d-%H%M')"
LOG_DIR="$SCRIPT_DIR/logs"
LOGFILE="$LOG_DIR/initial-setup-$TIMESTAMP.log"
ROM_SHA1="579C48E211AE952530FFC8738709F078D5DD215E"

mkdir -p "$LOG_DIR"
echo "🛠 spmc-initial-setup.sh v$VERSION — $(date)" | tee -a "$LOGFILE"
echo "   macOS: $(sw_vers -productName) $(sw_vers -productVersion)" | tee -a "$LOGFILE"
echo "   Arch:  $(uname -m)" | tee -a "$LOGFILE"

# ── Architecture guard ────────────────────────────────────────────────────────

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "⚠️  Non-Intel architecture detected ($(uname -m))." | tee -a "$LOGFILE"
  echo "   This project targets Intel x86_64 Macs." | tee -a "$LOGFILE"
  echo "   On Apple Silicon, use Rosetta 2 or build a native arm64 variant." | tee -a "$LOGFILE"
fi

# ── Step 1: Xcode Command Line Tools ─────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🔧 Step 1: Xcode Command Line Tools" | tee -a "$LOGFILE"
if ! xcode-select -p &>/dev/null; then
  echo "   Not found — launching installer." | tee -a "$LOGFILE"
  echo "   Complete the GUI prompt, then re-run this script." | tee -a "$LOGFILE"
  xcode-select --install
  exit 0
fi
echo "   ✅ $(xcode-select -p)" | tee -a "$LOGFILE"

# ── Step 2: Homebrew ──────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "🍺 Step 2: Homebrew" | tee -a "$LOGFILE"
if ! command -v brew &>/dev/null; then
  echo "   Installing Homebrew..." | tee -a "$LOGFILE"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1 | tee -a "$LOGFILE"
  # Intel Mac: Homebrew prefix is /usr/local on all macOS versions including Tahoe
  eval "$(/usr/local/bin/brew shellenv)"
fi
echo "   ✅ $(brew --version | head -1)" | tee -a "$LOGFILE"

# ── Step 3: Homebrew packages ─────────────────────────────────────────────────

# SpaghettiKart BUILDING.md macOS deps:
#   sdl2, libpng, glew, ninja, cmake, nlohmann-json, libzip,
#   vorbis-tools, sdl2_net, tinyxml2
# Additional from CMakeLists.txt / libultraship:
#   spdlog, boost, libogg, libvorbis, python3, git

echo "" | tee -a "$LOGFILE"
echo "📦 Step 3: Homebrew packages" | tee -a "$LOGFILE"
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

# ── Step 4: ROM status ────────────────────────────────────────────────────────

# SpaghettiKart only supports the US ROM.
# The ROM is placed in the central roms/ directory (gitignored).
# The build script copies it into SpaghettiKart/ for the ExtractAssets target.

echo "" | tee -a "$LOGFILE"
echo "🎮 Step 4: ROM status" | tee -a "$LOGFILE"
echo "   Checking roms/ directory: $SCRIPT_DIR/roms/" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

ROM_PATH="$SCRIPT_DIR/roms/mk64.us.z64"
if [[ -f "$ROM_PATH" ]]; then
  ACTUAL_SHA1="$(shasum -a 1 "$ROM_PATH" | awk '{print toupper($1)}')"
  if [[ "$ACTUAL_SHA1" == "$ROM_SHA1" ]]; then
    echo "   ✅ 🇺🇸 Mario Kart 64 US — $(du -h "$ROM_PATH" | cut -f1)  SHA-1 OK" | tee -a "$LOGFILE"
  else
    echo "   ⚠️  🇺🇸 Mario Kart 64 US — SHA-1 MISMATCH" | tee -a "$LOGFILE"
    echo "       got:      $ACTUAL_SHA1" | tee -a "$LOGFILE"
    echo "       expected: $ROM_SHA1" | tee -a "$LOGFILE"
    echo "       ROM must be US version in .z64 format" | tee -a "$LOGFILE"
  fi
else
  echo "   · 🇺🇸 Mario Kart 64 US — not present → roms/mk64.us.z64" | tee -a "$LOGFILE"
  echo "     SHA-1: $ROM_SHA1" | tee -a "$LOGFILE"
  echo "     Must be US version in .z64 format (convert .n64 if needed)" | tee -a "$LOGFILE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"
echo "✅ spmc-initial-setup.sh v$VERSION complete!" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"
echo "   Next steps:" | tee -a "$LOGFILE"
echo "   1. Place ROM in roms/mk64.us.z64  (US, .z64 format)" | tee -a "$LOGFILE"
echo "   2. ./spmc-build.sh                # clone, extract assets, compile" | tee -a "$LOGFILE"
echo "   3. ./run-spmc-macos.sh            # launch SpaghettiKart" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"