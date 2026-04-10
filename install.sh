#!/usr/bin/env bash
set -euo pipefail

#======================================================================
# bootstrap-rails installer
#
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/streed/bootstrap-project/main/install.sh | bash
#
# What this does:
#   1. Clones the repo to ~/.bootstrap-rails
#   2. Symlinks the CLI into ~/.local/bin (or /usr/local/bin)
#   3. Verifies PATH includes the bin directory
#======================================================================

REPO="streed/bootstrap-project"
INSTALL_DIR="${HOME}/.bootstrap-rails"
USER_BIN_DIR="${HOME}/.local/bin"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check for git
if ! command -v git &>/dev/null; then
  log_error "git is required. Please install git and try again."
  exit 1
fi

echo ""
echo -e "${BOLD}bootstrap-rails installer${NC}"
echo "========================="
echo ""

#----------------------------------------------------------------------
# Step 1: Clone or update the repo
#----------------------------------------------------------------------
if [[ -d "${INSTALL_DIR}" ]]; then
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    log_info "Existing installation found. Updating..."
    cd "$INSTALL_DIR"
    git fetch origin main --quiet
    git reset --hard origin/main --quiet
    log_ok "Updated to latest version."
  else
    log_warn "Directory ${INSTALL_DIR} exists but is not a git repo."
    log_info "Backing up and re-installing..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%s)"
    git clone --depth 1 "https://github.com/${REPO}.git" "$INSTALL_DIR" --quiet
    log_ok "Cloned fresh copy."
  fi
else
  log_info "Installing to ${INSTALL_DIR}..."
  git clone --depth 1 "https://github.com/${REPO}.git" "$INSTALL_DIR" --quiet
  log_ok "Repository cloned."
fi

#----------------------------------------------------------------------
# Step 2: Make scripts executable
#----------------------------------------------------------------------
chmod +x "${INSTALL_DIR}/generate.sh"
chmod +x "${INSTALL_DIR}/bin/bootstrap-rails"

#----------------------------------------------------------------------
# Step 3: Symlink into PATH
#----------------------------------------------------------------------
mkdir -p "$USER_BIN_DIR"

ln -sf "${INSTALL_DIR}/bin/bootstrap-rails" "${USER_BIN_DIR}/bootstrap-rails"
log_ok "Linked: ${USER_BIN_DIR}/bootstrap-rails"

#----------------------------------------------------------------------
# Step 4: Check PATH
#----------------------------------------------------------------------
VERSION="$(cat "${INSTALL_DIR}/VERSION" 2>/dev/null || echo "unknown")"

if echo "$PATH" | tr ':' '\n' | grep -qx "$USER_BIN_DIR"; then
  log_ok "Installed bootstrap-rails v${VERSION}"
  echo ""
  echo "You're all set! Run:"
  echo ""
  echo "  bootstrap-rails my_app"
  echo ""
else
  log_warn "${USER_BIN_DIR} is not in your PATH."
  echo ""
  echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
  echo ""
  echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
  echo ""
  echo "Then restart your terminal, or run:"
  echo ""
  echo "  source ~/.bashrc  # or ~/.zshrc"
  echo ""
  echo "After that:"
  echo ""
  echo "  bootstrap-rails my_app"
  echo ""
fi

echo -e "To update later:   ${BOLD}bootstrap-rails --update${NC}"
echo -e "To uninstall:       ${BOLD}~/.bootstrap-rails/uninstall.sh${NC}"
echo ""
