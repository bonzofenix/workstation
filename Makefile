SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c ${SHELLFLAGS}
NO_BREW?=false
DEBUG?=false
default: install

# This will grab all targets in the Makefile and make them PHONY
.PHONY: $(MAKECMDGOALS)

install: check-dependencies cache-password homebrew git git-aliases configurations osx-configurations nix claude-skills claude-configs
	@echo "Reloading Bash..."
	@source ~/.bash_profile

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

git-aliases:
	@DEBUG="${DEBUG}" ./lib/git.sh

configurations:
	@DEBUG="${DEBUG}" ./lib/configurations.sh

osx-configurations:
	@DEBUG="${DEBUG}" ./lib/osx-configurations.sh

git:
	@DEBUG="${DEBUG}" ./lib/git.sh

claude-skills:
	@DEBUG="${DEBUG}" ./lib/claude-skills.sh

claude-configs:
	@DEBUG="${DEBUG}" ./lib/claude-configs.sh

lint:
	@echo "Running shellcheck on all scripts..."
	@./bin/lint

check-deps:
	@./bin/check-deps
