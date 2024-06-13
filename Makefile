SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c ${SHELLFLAGS}
NO_BREW?=false
DEBUG?=false

.PHONY: install
install:
	@NO_BREW="${NO_BREW}" DEBUG="${DEBUG}" ./scripts/install.sh


