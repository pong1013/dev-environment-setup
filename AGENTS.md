# Repository working agreement

## Architecture

- `scripts/chien-dev` sources every Bash file into one process; preserve its load order and `set -euo pipefail` behavior.
- Keep command orchestration in `scripts/commands/`, reusable backend operations in `scripts/modules/`, validation and paths in `scripts/core/`, and generated-file rendering in `scripts/generators/`.
- Treat `templates/` as inactive examples until the generators explicitly consume them. Runtime output belongs under ignored `generated/` paths.

## Safety and compatibility

- Preserve both DevContainer and Multipass behavior unless the task explicitly narrows scope.
- Destructive commands must validate the exact environment, refuse uncertain or running state, ask for confirmation, and re-check state after confirmation before deleting anything.
- Keep interactive flows and documented non-interactive flags compatible. Never treat generated development credentials as production-safe.

## Change workflow

- Discover existing behavior before adding it, then make the smallest coherent change.
- Update tests for behavior changes. Keep CLI help plus `README.md` and `README.zh-TW.md` aligned when user-facing commands or options change.
- Run `make verify` before handing off. State any Docker or Multipass behavior that could not be exercised locally.

