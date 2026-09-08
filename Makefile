SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c ${SHELLFLAGS}
NO_BREW?=false
DEBUG?=false
# Go toolchain installed by linux-server; override to match a project's
# .tool-versions when it needs a different one.
GO_VERSION?=1.25.14
default: install

# This will grab all targets in the Makefile and make them PHONY
.PHONY: $(MAKECMDGOALS)

install: check-dependencies cache-password homebrew git configurations osx-configurations nix npm-globals claude-configs devbox
	@source ~/.bash_profile
	@gum style --foreground 2 --bold "  Installation complete!"

# Linux workstation: the same shell, git and Claude setup as macOS, without
# Homebrew or the osx-configurations defaults writes.
install-linux: linux-packages git linux-configurations claude-configs
	@echo "  Linux installation complete. Open a new shell to pick it up."

# Adds what a VPS needs on top of install-linux: Go, PostgreSQL, Caddy,
# Garmin sync deps, a default-deny firewall and daily off-site backups.
install-server: install-linux linux-server linux-backups
	@echo "  Server setup complete."

linux-packages:
	@DEBUG="${DEBUG}" ./lib/linux-packages.sh

linux-configurations:
	@DEBUG="${DEBUG}" ./lib/linux-configurations.sh

linux-server:
	@DEBUG="${DEBUG}" GO_VERSION="${GO_VERSION}" ./lib/linux-server.sh

linux-backups:
	@DEBUG="${DEBUG}" ./lib/linux-backups.sh

# Not part of install-server: creating the tunnel needs an interactive
# browser login, so this installs cloudflared and then hands off to a
# documented manual sequence.
linux-tunnel:
	@DEBUG="${DEBUG}" ./lib/linux-tunnel.sh

check-dependencies:
	@./lib/check-dependencies.sh

cache-password:
	@echo "Caching password..."
	@sudo -K
	@sudo true;

homebrew:
	@NO_BREW="${NO_BREW}" DEBUG="${DEBUG}" ./lib/homebrew.sh

block-content:
	@DEBUG="${DEBUG}" ./lib/block-content.sh

nix:
	@DEBUG="${DEBUG}" ./lib/nix.sh

npm-globals:
	@DEBUG="${DEBUG}" ./lib/npm-globals.sh

git-aliases:
	@DEBUG="${DEBUG}" ./lib/git.sh

configurations:
	@DEBUG="${DEBUG}" ./lib/configurations.sh

osx-configurations:
	@DEBUG="${DEBUG}" ./lib/osx-configurations.sh

git:
	@DEBUG="${DEBUG}" ./lib/git.sh

claude-configs:
	@DEBUG="${DEBUG}" ./lib/claude-configs.sh

devbox:
	@DEBUG="${DEBUG}" ./lib/devbox.sh

lint:
	@echo "Running shellcheck on all scripts..."
	@./bin/lint

check-deps:
	@./bin/check-deps
