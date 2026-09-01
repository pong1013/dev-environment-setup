SHELL := /bin/bash
FIRST_GOAL := $(firstword $(MAKECMDGOALS))
EXTRA_GOALS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

.PHONY: chien-dev start create stop status doctor shell clean test
chien-dev:
	@./scripts/chien-dev $(EXTRA_GOALS)

test:
	@bash tests/clean_test.sh

start create stop status doctor shell clean:
	@if [ "$(FIRST_GOAL)" = "$@" ]; then ./scripts/chien-dev $@ $(filter-out $@,$(MAKECMDGOALS)); fi

%:
	@:
