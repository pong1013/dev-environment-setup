SHELL := /bin/bash
FIRST_GOAL := $(firstword $(MAKECMDGOALS))
EXTRA_GOALS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

.PHONY: chien-dev start create stop status doctor shell clean test verify harness-audit
chien-dev:
	@./scripts/chien-dev $(EXTRA_GOALS)

test:
	@bash tests/run.sh

verify:
	@bash scripts/verify.sh

harness-audit:
	@bash scripts/harness-audit.sh $(if $(filter 1,$(TRUSTED)),--trusted,)

start create stop status doctor shell clean:
	@if [ "$(FIRST_GOAL)" = "$@" ]; then ./scripts/chien-dev $@ $(filter-out $@,$(MAKECMDGOALS)); fi

%:
	@:
