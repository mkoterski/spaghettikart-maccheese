#!/usr/bin/env bash
# ============================================================================
# setup-wip-test.sh — SpaghettiKart macOS WIP Test Environment Setup
# Project: spaghettikart-maccheese
# Version: v0.2
# ============================================================================
#
# Creates an isolated, git-ignored test folder within the repo for evaluating
# the WIP macOS Intel build from HarbourMasters Discord.
#
# KNOWN ISSUE (GH #681): Both Metal and OpenGL backends crash with
# EXC_ARITHMETIC (SIGFPE) on track load on Intel Iris Plus Graphics
# (MacBookPro16,2). Metal also renders a black screen from launch.
# This script pre-configures OpenGL (Backend Id 1) as a workaround
# for the black-screen issue — menus at least render correctly.
# The track-load SIGFPE remains unresolved upstream.
#
# Usage:
#   chmod +x setup-wip-test.sh
#   ./setup-wip-test.sh [path-to-rom.z64]
#
# If no ROM path is provided, the script will prompt for it.
#
# Changelog:
#   v0.2  - Pre-configure OpenGL backend for portable build (GH #681)
#         - Add config.json with correct "Id" key (capital I, not "id")
#         - Config placed next to binary (portable build reads locally)
#         - Add crash log capture to launch.sh
#         - Add known-issue warning at setup completion
#   v0.1  - Initial setup script
# ============================================================================

set -euo pipefail

# --- Colors & Formatting ---------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Config -----------------------------------------------------------------
REPO_DIR="/Users/matthias/Documents/GitHub/spaghettikart-maccheese"
WIP_ZIP="/Users/matthias/Downloads/spaghetti-mac-intel-x64.zip"
WIP_SRC="/Users/matthias/Downloads/spaghetti-mac-intel-x64"
TEST_DIR="${REPO_DIR}/wip-test"
GITIGNORE="${REPO_DIR}/.gitignore"
LOG_DIR="${TEST_DIR}/logs"
LOG_FILE="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"

# --- Functions --------------------------------------------------------------
banner() {
  echo ""
  echo -e "${CYAN}${BOLD}============================================================================${NC}"
  echo -e "${CYAN}${BOLD}  SpaghettiKart macOS WIP — Test Environment Setup${NC}"
  echo -e "${CYAN}${BOLD}  v0.2 — spaghettikart-maccheese${NC}"
  echo -e "${CYAN}${BOLD}============================================================================${NC}"
  echo ""
}

log() {
  local level="$1"; shift
  local timestamp; timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  local icon
  case "${level}" in
    INFO)  icon="ℹ️ "; color="${GREEN}" ;;
    WARN)  icon="⚠️ "; color="${YELLOW}" ;;
    ERROR) icon="❌"; color="${RED}" ;;
    *)     icon="  "; color="${NC}" ;;
  esac
  echo -e "${color}${icon} ${*}${NC}"
  echo "[${timestamp}] [${level}] ${*}" >> "${LOG_FILE}" 2>/dev/null || true
}

check_prereqs() {
  if [[ ! -d "${REPO_DIR}" ]]; then
    log ERROR "Repo not found at ${REPO_DIR}"
    exit 1
  fi

  if [[ ! -d "${WIP_SRC}" ]]; then
    if [[ -f "${WIP_ZIP}" ]]; then
      log INFO "Extracted folder not found — unzipping ${WIP_ZIP} ..."
      unzip -q "${WIP_ZIP}" -d "$(dirname "${WIP_ZIP}")"
      if [[ ! -d "${WIP_SRC}" ]]; then
        log ERROR "Unzip succeeded but expected folder not found at ${WIP_SRC}"
        log ERROR "Check zip structure — folder name inside may differ"
        exit 1
      fi
      log INFO "Extracted to ${WIP_SRC}"
    else
      log ERROR "Neither extracted folder nor zip found:"
      log ERROR "  Folder: ${WIP_SRC}"
      log ERROR "  Zip:    ${WIP_ZIP}"
      exit 1
    fi
  fi

  if [[ ! -f "${WIP_SRC}/Spaghettify" ]]; then
    log ERROR "Spaghettify binary not found in ${WIP_SRC}/"
    exit 1
  fi
}

setup_gitignore() {
  local entry="wip-test/"

  if [[ ! -f "${GITIGNORE}" ]]; then
    log INFO "Creating .gitignore"
    echo "${entry}" > "${GITIGNORE}"
    log INFO "Added '${entry}' to .gitignore"
    return
  fi

  if grep -qxF "${entry}" "${GITIGNORE}" 2>/dev/null; then
    log INFO ".gitignore already contains '${entry}' — skipping"
  else
    echo "" >> "${GITIGNORE}"
    echo "# WIP test environment (not tracked)" >> "${GITIGNORE}"
    echo "${entry}" >> "${GITIGNORE}"
    log INFO "Added '${entry}' to .gitignore"
  fi
}

create_test_dir() {
  if [[ -d "${TEST_DIR}" ]]; then
    log WARN "Test directory already exists at ${TEST_DIR}"
    read -rp "  Overwrite contents? [y/N]: " confirm
    if [[ "${confirm}" != [yY] ]]; then
      log INFO "Aborted by user"
      exit 0
    fi
    rm -rf "${TEST_DIR}"
  fi

  mkdir -p "${TEST_DIR}"
  mkdir -p "${LOG_DIR}"
  log INFO "Created ${TEST_DIR}"
}

copy_wip_build() {
  log INFO "Copying WIP build from ${WIP_SRC}/ ..."
  cp -R "${WIP_SRC}/"* "${TEST_DIR}/"
  chmod +x "${TEST_DIR}/Spaghettify"

  # Strip macOS Gatekeeper quarantine flag — downloaded binaries (e.g. from
  # Discord) are tagged with com.apple.quarantine and will be Killed: 9
  log INFO "Stripping quarantine attributes (Gatekeeper) ..."
  xattr -cr "${TEST_DIR}/"
  log INFO "WIP build copied — Spaghettify marked executable, quarantine cleared"
}

configure_opengl_backend() {
  # GH #681: Metal (Id 2, default) renders a black screen on Intel Iris Plus.
  # OpenGL (Id 1) at least renders menus correctly before the track-load crash.
  #
  # Key must be "Id" (capital I) — lowercase "id" is silently ignored by
  # Config::GetInt("Window.Backend.Id") in libultraship.
  #
  # Portable builds read config from their own directory, not ~/spaghettify.cfg.json.

  local config_file="${TEST_DIR}/spaghettify.cfg.json"

  if [[ -f "${config_file}" ]]; then
    log INFO "Config file already exists — checking backend setting"
    # If the shipped config already exists, patch it to OpenGL if needed
    if command -v python3 &>/dev/null; then
      python3 -c "
import json, sys
cfg_path = '${config_file}'
with open(cfg_path, 'r') as f:
    cfg = json.load(f)
window = cfg.setdefault('Window', {})
backend = window.setdefault('Backend', {})
if backend.get('Id') != 1:
    backend['Id'] = 1
    backend['Name'] = 'OpenGL'
    with open(cfg_path, 'w') as f:
        json.dump(cfg, f, indent=4)
    print('patched')
else:
    print('already_opengl')
" 2>/dev/null
      local result=$?
      if [[ ${result} -eq 0 ]]; then
        log INFO "Config set to OpenGL backend (Id: 1) — GH #681 workaround"
      fi
    else
      log WARN "python3 not found — writing fresh config"
      write_opengl_config "${config_file}"
    fi
  else
    write_opengl_config "${config_file}"
  fi
}

write_opengl_config() {
  local config_file="$1"
  cat > "${config_file}" << 'CFG'
{
    "Window": {
        "Backend": {
            "Id": 1,
            "Name": "OpenGL"
        }
    }
}
CFG
  log INFO "Created ${config_file} with OpenGL backend (Id: 1)"
  log INFO "GH #681: Metal renders black screen on Intel Iris Plus — using OpenGL"
}

copy_rom() {
  local rom_path="$1"

  if [[ ! -f "${rom_path}" ]]; then
    log ERROR "ROM not found: ${rom_path}"
    exit 1
  fi

  if [[ "${rom_path}" != *.z64 ]]; then
    log WARN "Expected .z64 ROM, got: ${rom_path##*.}"
    log WARN "Proceeding anyway — extraction may fail if format is wrong"
  fi

  local rom_name; rom_name="$(basename "${rom_path}")"
  cp "${rom_path}" "${TEST_DIR}/${rom_name}"
  log INFO "ROM copied: ${rom_name}"
  echo "${rom_name}"
}

run_extraction() {
  local rom_name="$1"
  log INFO "Running asset extraction via Spaghettify ..."
  log INFO "  ROM: ${rom_name}"
  echo ""

  cd "${TEST_DIR}"
  ./Spaghettify "${rom_name}" 2>&1 | tee -a "${LOG_FILE}"
  local exit_code=${PIPESTATUS[0]}

  if [[ ${exit_code} -ne 0 ]]; then
    log WARN "Spaghettify exited with code ${exit_code}"
    log WARN "Check the log for details: ${LOG_FILE}"
    log WARN "The game may still work — some extractors return non-zero on warnings"
  else
    log INFO "Asset extraction completed successfully"
  fi
}

create_launch_script() {
  local launch="${TEST_DIR}/launch.sh"
  cat > "${launch}" << 'LAUNCH'
#!/usr/bin/env bash
# launch.sh — Start SpaghettiKart WIP build
# Logs stdout/stderr for crash analysis (GH #681)
cd "$(dirname "$0")"

LOG_DIR="./logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/run-$(date +%Y%m%d-%H%M%S).log"

echo "Starting SpaghettiKart (WIP macOS Intel build)..."
echo "  Backend: OpenGL (Id 1) — see spaghettify.cfg.json"
echo "  Log:     ${LOG_FILE}"
echo ""
echo "⚠️  KNOWN ISSUE (GH #681): Track load crashes with SIGFPE on Intel Iris Plus."
echo "  Menus should render. Crash expected when selecting a track."
echo ""

./Spaghettify 2>&1 | tee "${LOG_FILE}"
EXIT_CODE=${PIPESTATUS[0]}

if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo ""
  echo "⚠️  Spaghettify exited with code ${EXIT_CODE}"
  echo "  Run log saved to: ${LOG_FILE}"
  echo "  macOS crash report: check Console.app → Crash Reports"
fi
LAUNCH
  chmod +x "${launch}"
  log INFO "Created launch.sh (with crash logging for GH #681 tracking)"
}

# --- Main -------------------------------------------------------------------
banner

# Init log (we need LOG_DIR to exist first, so create minimally)
mkdir -p "${LOG_DIR}" 2>/dev/null || true
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Setup started" > "${LOG_FILE}"

log INFO "Checking prerequisites ..."
check_prereqs

# ROM path — from argument or prompt
ROM_PATH="${1:-}"
if [[ -z "${ROM_PATH}" ]]; then
  echo ""
  read -rp "  Path to your .z64 ROM: " ROM_PATH
  # Expand tilde if present
  ROM_PATH="${ROM_PATH/#\~/$HOME}"
fi

setup_gitignore
create_test_dir
copy_wip_build
configure_opengl_backend
ROM_NAME="$(copy_rom "${ROM_PATH}")"

echo ""
read -rp "  Run asset extraction now? [Y/n]: " run_extract
if [[ "${run_extract}" != [nN] ]]; then
  run_extraction "${ROM_NAME}"
fi

create_launch_script

echo ""
echo -e "${GREEN}${BOLD}============================================================================${NC}"
echo -e "${GREEN}${BOLD}  Setup complete!${NC}"
echo -e "${GREEN}${BOLD}============================================================================${NC}"
echo ""
log INFO "Test environment ready at: ${TEST_DIR}"
log INFO "To launch:  cd ${TEST_DIR} && ./launch.sh"
log INFO "Full log:   ${LOG_FILE}"
echo ""
echo -e "${YELLOW}${BOLD}  ⚠️  GH #681 REMINDER:${NC}"
echo -e "${YELLOW}  Both Metal and OpenGL crash with SIGFPE on track load on your GPU.${NC}"
echo -e "${YELLOW}  This build is pre-configured for OpenGL (menus render correctly).${NC}"
echo -e "${YELLOW}  The track-load crash is an upstream issue — compare WIP behavior${NC}"
echo -e "${YELLOW}  against your issue report to see if this Discord build differs.${NC}"
echo ""