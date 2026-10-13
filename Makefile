SHELL_FILES := bin/file-cleaner $(wildcard scripts/*.sh lib/*.sh cleaners/*.sh validators/*.sh tests/*.sh)

.PHONY: check lint test

check: lint test

lint:
	@command -v shellcheck >/dev/null || { echo "shellcheck not installed (pip install shellcheck-py)"; exit 1; }
	shellcheck -x $(SHELL_FILES)

test:
	tests/run.sh
