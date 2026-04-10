SHELL := /bin/bash
PREFIX ?= /usr/local
INSTALL_DIR = $(HOME)/.bootstrap-rails
BIN_DIR = $(PREFIX)/bin

VERSION := $(shell cat VERSION 2>/dev/null || echo "dev")

.PHONY: help install uninstall update link version

help: ## Show this help message
	@echo "bootstrap-rails v$(VERSION)"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Usage:"
	@echo "  make install           # Install to ~/.bootstrap-rails + $(BIN_DIR)"
	@echo "  make install PREFIX=~  # Install to ~/.bootstrap-rails + ~/bin"
	@echo "  make uninstall         # Remove everything"
	@echo "  make update            # Pull latest and reinstall"

install: ## Install bootstrap-rails to your system
	@echo "Installing bootstrap-rails v$(VERSION)..."
	@mkdir -p $(INSTALL_DIR)
	@cp -r templates $(INSTALL_DIR)/
	@cp generate.sh $(INSTALL_DIR)/
	@cp VERSION $(INSTALL_DIR)/
	@mkdir -p $(INSTALL_DIR)/bin
	@cp bin/bootstrap-rails $(INSTALL_DIR)/bin/
	@chmod +x $(INSTALL_DIR)/generate.sh $(INSTALL_DIR)/bin/bootstrap-rails
	@cp uninstall.sh $(INSTALL_DIR)/
	@chmod +x $(INSTALL_DIR)/uninstall.sh
	@mkdir -p $(BIN_DIR)
	@ln -sf $(INSTALL_DIR)/bin/bootstrap-rails $(BIN_DIR)/bootstrap-rails
	@echo ""
	@echo "Installed bootstrap-rails v$(VERSION)"
	@echo "  Binary:    $(BIN_DIR)/bootstrap-rails"
	@echo "  Data:      $(INSTALL_DIR)/"
	@echo ""
	@echo "Run: bootstrap-rails my_app"

uninstall: ## Remove bootstrap-rails from your system
	@echo "Uninstalling bootstrap-rails..."
	@rm -f $(BIN_DIR)/bootstrap-rails
	@rm -f $(HOME)/.local/bin/bootstrap-rails
	@rm -rf $(INSTALL_DIR)
	@echo "Done."

update: ## Pull latest changes and reinstall
	@if [ -d "$(INSTALL_DIR)/.git" ]; then \
		echo "Updating from git..."; \
		cd $(INSTALL_DIR) && git pull origin main --quiet; \
		echo "Updated to v$$(cat $(INSTALL_DIR)/VERSION 2>/dev/null || echo 'unknown')"; \
	elif command -v git >/dev/null 2>&1; then \
		echo "Re-cloning from GitHub..."; \
		rm -rf $(INSTALL_DIR); \
		git clone --depth 1 https://github.com/streed/bootstrap-project.git $(INSTALL_DIR) --quiet; \
		chmod +x $(INSTALL_DIR)/generate.sh $(INSTALL_DIR)/bin/bootstrap-rails; \
		mkdir -p $(BIN_DIR); \
		ln -sf $(INSTALL_DIR)/bin/bootstrap-rails $(BIN_DIR)/bootstrap-rails; \
		echo "Updated to v$$(cat $(INSTALL_DIR)/VERSION 2>/dev/null || echo 'unknown')"; \
	else \
		echo "ERROR: git is required to update."; \
		exit 1; \
	fi

link: ## Symlink from this repo checkout (for development)
	@echo "Linking bootstrap-rails from this checkout..."
	@mkdir -p $(HOME)/.local/bin
	@ln -sf $(CURDIR)/bin/bootstrap-rails $(HOME)/.local/bin/bootstrap-rails
	@echo "Linked: $(HOME)/.local/bin/bootstrap-rails -> $(CURDIR)/bin/bootstrap-rails"
	@echo ""
	@echo "For development, changes to this repo are reflected immediately."

version: ## Show current version
	@echo "bootstrap-rails v$(VERSION)"
