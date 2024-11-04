SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c ${SHELLFLAGS}
NO_BREW?=false
DEBUG?=false

.PHONY: install
install: cache-password homebrew asdf git git-alias configurations osx-configurations
	@echo "Reloading Bash..."
	@source ~/.bash_profile

.PHONY: cache-password
cache-password:
	@echo "Caching password..."
	@sudo -K
	@sudo true;

.PHONY: homebrew
homebrew:
	@NO_BREW="${NO_BREW}" DEBUG="${DEBUG}" ./lib/homebrew.sh

.PHONY: git-alias
git-alias:
	@DEBUG="${DEBUG}" ./lib/git-aliase.sh

.PHONY: configurations
configurations:
	@DEBUG="${DEBUG}" ./lib/configurations.sh

.PHONY: osx-configurations
osx-configurations:
	@DEBUG="${DEBUG}" ./lib/osx-configurations.sh

.PHONY: asdf
asdf:
	@DEBUG="${DEBUG}" ./lib/asdf.sh

.PHONY: git
git:
	@DEBUG="${DEBUG}" ./lib/git.sh


