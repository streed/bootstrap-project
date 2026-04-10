#!/usr/bin/env bash
set -euo pipefail

#======================================================================
# bootstrap-rails uninstaller
#
# Removes:
#   - ~/.bootstrap-rails/         (source files and templates)
#   - ~/.local/bin/bootstrap-rails (CLI symlink)
#   - /usr/local/bin/bootstrap-rails (if installed via Makefile)
#======================================================================

INSTALL_DIR="${HOME}/.bootstrap-rails"
USER_BIN="${HOME}/.local/bin/bootstrap-rails"
SYSTEM_BIN="/usr/local/bin/bootstrap-rails"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}bootstrap-rails uninstaller${NC}"
echo "==========================="
echo ""

# Confirm
read -rp "Remove bootstrap-rails and all its files? [y/N] " confirm
if [[ ! "$confirm" =~ ^[yY] ]]; then
  echo "Cancelled."
  exit 0
fi

removed=false

# Remove user-local symlink
if [[ -L "$USER_BIN" ]] || [[ -f "$USER_BIN" ]]; then
  rm -f "$USER_BIN"
  echo -e "${GREEN}[OK]${NC}    Removed ${USER_BIN}"
  removed=true
fi

# Remove system symlink (may need sudo)
if [[ -L "$SYSTEM_BIN" ]] || [[ -f "$SYSTEM_BIN" ]]; then
  if [[ -w "$(dirname "$SYSTEM_BIN")" ]]; then
    rm -f "$SYSTEM_BIN"
  else
    sudo rm -f "$SYSTEM_BIN"
  fi
  echo -e "${GREEN}[OK]${NC}    Removed ${SYSTEM_BIN}"
  removed=true
fi

# Remove install directory
if [[ -d "$INSTALL_DIR" ]]; then
  rm -rf "$INSTALL_DIR"
  echo -e "${GREEN}[OK]${NC}    Removed ${INSTALL_DIR}"
  removed=true
fi

if $removed; then
  echo ""
  echo -e "${GREEN}bootstrap-rails has been uninstalled.${NC}"
else
  echo ""
  echo -e "${YELLOW}Nothing to remove. bootstrap-rails does not appear to be installed.${NC}"
fi
echo ""
