SHELL := /bin/bash
FIRST_GOAL := $(firstword $(MAKECMDGOALS))
EXTRA_GOALS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

.PHONY: chien-dev start init stop status doctor shell clean
chien-dev:
	@./scripts/chien-dev $(EXTRA_GOALS)

start init stop status doctor shell clean:
	@if [ "$(FIRST_GOAL)" = "$@" ]; then ./scripts/chien-dev $@ $(filter-out $@,$(MAKECMDGOALS)); fi

%:
	@:
