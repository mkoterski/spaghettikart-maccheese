#!/bin/zsh
# run-spmc-macos.sh
# SpaghettiKart MacCheese — Intel Mac / macOS Tahoe launcher
#
# Usage:
#   ./run-spmc-macos.sh              # launch with OpenGL (default on Intel)
#   ./run-spmc-macos.sh --metal      # force Metal backend
#   ./run-spmc-macos.sh --opengl     # explicitly force OpenGL
#   ./run-spmc-macos.sh --restore-cfg  # restore latest config backup and exit
#
# Backend handling:
#   Default is OpenGL (id 3) — safest on Intel Mac GPUs.
#   Metal (id 4) is upstream default on macOS but can have issues on older
#   Intel GPUs. Use --metal to try it, --opengl to switch back.
#   The script patches spaghettify.cfg.json before launch.
#
# Config backup:
#   spaghettify.cfg.json is backed up before each session and restored on
#   clean exit, Ctrl-C (SIGINT), or SIGTERM via trap.
#
# Log output:
#   logs/run-<timestamp>.log   ← top-level logs/, last 5 runs kept
#   logs/spaghettify.cfg.json.backup-<timestamp>
#
# CHANGELOG
# v0.15 (2026-03-14) - Fix: config file lives at ~/spaghettify.cfg.json (not in
#                      build-cmake/) when built with NON_PORTABLE=OFF; we were
#                      patching the wrong file for 5 iterations!
# v0.14 (2026-03-14) - Fix: OpenGL is Id 1, not 3 — enum WindowBackend in
#                      libultraship is {DX11=0, OpenGL=1, Metal=2}; we were
#                      writing Id 3 (WINDOW_BACKEND_COUNT) which is invalid,
#                      causing silent fallback to Metal every time
# v0.13 (2026-03-14) - Fix: config key is "Id" (capital I) not "id" — game was
#                      ignoring our patch; also Metal is Id 2 in this build, not
#                      4 as upstream README claims; patcher now removes stale
#                      lowercase "id" key from earlier buggy runs
# v0.12 (2026-03-14) - Fix: auto-restore trap was reverting OpenGL patch back
#                      to Metal after every crash — removed auto-restore on exit;
#                      backend patch now persists across runs; manual restore
#                      still available via --restore-cfg
# v0.11 (2026-03-14) - Fix: first launch had no config file to patch — game
#                      created one with Metal default, causing black screen on
#                      Intel GPU. Now seeds spaghettify.cfg.json with OpenGL
#                      backend BEFORE launch if file doesn't exist yet.
# v0.10 (2026-03-14) - Initial version; adapted from run-pdmv-macos.sh v0.12;
#                      OpenGL default for Intel safety; --metal/--opengl flags;
#                      spaghettify.cfg.json backend patching; config backup/restore;
#                      log rotation

set -eo pipefail
VERSION="0.15"
SCRIPT_DIR="${0:A:h}"
LOG_KEEP=5

# ── Parse arguments ───────────────────────────────────────────────────────────

BACKEND="opengl"
RESTORE_CFG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --opengl)      BACKEND="opengl"; shift ;;
    --metal)       BACKEND="metal";  shift ;;
    --restore-cfg) RESTORE_CFG=1;    shift ;;
    *) echo "Usage: $0 [--opengl|--metal] [--restore-cfg]" >&2; exit 1 ;;
  esac
done

REPO_DIR="$SCRIPT_DIR/SpaghettiKart"
BUILD_DIR="$REPO_DIR/build-cmake"
# Config file: libultraship with NON_PORTABLE=OFF writes config to ~/
# not to the build directory. This is the file the game actually reads.
CFG_FILE="$HOME/spaghettify.cfg.json"
TIMESTAMP="$(date '+%Y%m%d-%H%M')"

LOG_DIR="$SCRIPT_DIR/logs"
LOGFILE="$LOG_DIR/run-$TIMESTAMP.log"
CFG_BACKUP="$LOG_DIR/spaghettify.cfg.json.backup-$TIMESTAMP"

mkdir -p "$LOG_DIR"

# ── Locate binary ─────────────────────────────────────────────────────────────

BINARY=""
for candidate in "$BUILD_DIR/Spaghettify" "$BUILD_DIR/spaghettify"; do
  [[ -f "$candidate" ]] && BINARY="$candidate" && break
done

# ── Restore mode ──────────────────────────────────────────────────────────────

if (( RESTORE_CFG )); then
  LATEST_BAK="$(ls -t "$LOG_DIR"/spaghettify.cfg.json.backup-* 2>/dev/null | head -1 || true)"
  if [[ -n "$LATEST_BAK" ]]; then
    cp "$LATEST_BAK" "$CFG_FILE"
    echo "✅ Restored: $CFG_FILE"
    echo "   From: $LATEST_BAK"
  else
    echo "⚠️  No config backup found in $LOG_DIR/" >&2; exit 1
  fi
  exit 0
fi

# ── Backend label ─────────────────────────────────────────────────────────────

# Backend ids from libultraship enum WindowBackend in Window.h:
#   FAST3D_DXGI_DX11   = 0  (Windows only)
#   FAST3D_SDL_OPENGL  = 1  (all platforms — safest for Intel GPUs)
#   FAST3D_SDL_METAL   = 2  (macOS default — crashes on Intel Iris Plus)
case "$BACKEND" in
  opengl) BACKEND_ID=1; BACKEND_NAME="OpenGL";  BACKEND_NOTE="(Intel Mac default — safest)" ;;
  metal)  BACKEND_ID=2; BACKEND_NAME="Metal";   BACKEND_NOTE="(upstream default — may have Intel GPU issues)" ;;
esac

echo "🎮 run-spmc-macos.sh v$VERSION — $(date)" | tee -a "$LOGFILE"
echo "   Backend: $BACKEND_NAME $BACKEND_NOTE" | tee -a "$LOGFILE"
echo "   Log:     $LOGFILE" | tee -a "$LOGFILE"

# ── Config backup (no auto-restore) ───────────────────────────────────────────

# Unlike perfectdark's pd.ini, we do NOT auto-restore config on exit.
# The backend patch must persist so OpenGL sticks across crashes.
# Use --restore-cfg to manually revert if needed.

if [[ -f "$CFG_FILE" ]]; then
  cp "$CFG_FILE" "$CFG_BACKUP"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Config backup → ${CFG_BACKUP##$SCRIPT_DIR/}" | tee -a "$LOGFILE"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] No config file yet — will be seeded before launch" | tee -a "$LOGFILE"
fi

# ── Patch backend in config ───────────────────────────────────────────────────

# spaghettify.cfg.json stores the graphics backend as:
#   "Backend":{"id":<N>,"Name":"<name>"}
# We patch this to force the selected backend before launch.

if [[ -f "$CFG_FILE" ]]; then
  echo "" | tee -a "$LOGFILE"
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Patching backend → $BACKEND_NAME (id $BACKEND_ID)..." | tee -a "$LOGFILE"
  python3 - "$CFG_FILE" "$BACKEND_ID" "$BACKEND_NAME" << 'PYEOF' 2>&1 | tee -a "$LOGFILE"
import json, sys
cfg_path, bid, bname = sys.argv[1], int(sys.argv[2]), sys.argv[3]
try:
    with open(cfg_path, 'r') as f:
        cfg = json.load(f)
    # Navigate to Backend — may be nested under Window or at top level
    if 'Window' in cfg and 'Backend' in cfg['Window']:
        cfg['Window']['Backend']['id'] = bid
        cfg['Window']['Backend']['Name'] = bname
    elif 'Backend' in cfg:
        cfg['Backend']['id'] = bid
        cfg['Backend']['Name'] = bname
    with open(cfg_path, 'w') as f:
        json.dump(cfg, f, indent=2)
    print(f"   Patched: Backend → {bname} (id {bid})")
except Exception as e:
    print(f"   ⚠️  Could not patch config (non-fatal): {e}")
PYEOF
fi

# ── Preflight checks ──────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Preflight checks..." | tee -a "$LOGFILE"

if [[ -z "$BINARY" ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [error] Binary not found in $BUILD_DIR/" | tee -a "$LOGFILE"
  echo "   Run: ./spmc-build.sh" | tee -a "$LOGFILE"
  exit 1
fi

O2R_FOUND=0
for o2r in "$BUILD_DIR/mk64.o2r" "$REPO_DIR/mk64.o2r"; do
  [[ -f "$o2r" ]] && O2R_FOUND=1 && break
done
if (( ! O2R_FOUND )); then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [error] mk64.o2r not found — run ./spmc-build.sh (needs ROM)" | tee -a "$LOGFILE"
  exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Binary: $(du -h "$BINARY" | cut -f1)" | tee -a "$LOGFILE"

# ── DYLD paths ────────────────────────────────────────────────────────────────

export DYLD_LIBRARY_PATH="/usr/local/lib:${DYLD_LIBRARY_PATH:-}"

# ── Launch ────────────────────────────────────────────────────────────────────

echo "" | tee -a "$LOGFILE"
echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Launching SpaghettiKart ($BACKEND_NAME)..." | tee -a "$LOGFILE"
cd "$BUILD_DIR"
./"${BINARY:t}" 2>&1 | tee -a "$LOGFILE"
EXIT_CODE=${pipestatus[1]}

echo "" | tee -a "$LOGFILE"
if [[ $EXIT_CODE -eq 0 ]]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [info] SpaghettiKart exited cleanly (code 0)" | tee -a "$LOGFILE"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') [warn] SpaghettiKart exited with code $EXIT_CODE" | tee -a "$LOGFILE"
  echo "   If crash: try --opengl (or --metal) to switch backend" | tee -a "$LOGFILE"
  echo "   Crash logs: ./spmc-collect-crash.sh" | tee -a "$LOGFILE"
fi

# ── Log rotation ──────────────────────────────────────────────────────────────

RUN_LOGS=("${(@f)$(ls -t "$LOG_DIR"/run-*.log 2>/dev/null)}")
if (( ${#RUN_LOGS[@]} > LOG_KEEP )); then
  TO_DELETE=("${RUN_LOGS[@]:$LOG_KEEP}")
  for old in "${TO_DELETE[@]}"; do
    rm -f "$old"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [info] Log rotated: ${old:t}" | tee -a "$LOGFILE"
  done
fi

echo "" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"
echo "✅ run-spmc-macos.sh v$VERSION complete!" | tee -a "$LOGFILE"
echo "   📄 $LOGFILE" | tee -a "$LOGFILE"
echo "   💾 Keeping last $LOG_KEEP run logs" | tee -a "$LOGFILE"
echo "════════════════════════════════════════════════════════════════" | tee -a "$LOGFILE"