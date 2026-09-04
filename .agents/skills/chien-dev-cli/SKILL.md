---
name: chien-dev-cli
description: Implement, diagnose, or review chien-dev CLI commands, flags, backends, generators, lifecycle behavior, documentation, and regression tests. Use for product behavior changes in this repository; do not use for maintaining the AI Harness itself.
---

# Chien Dev CLI

Keep changes small and preserve the CLI's existing architecture and safety properties.

## Locate the change

- Command flow: `scripts/commands/<command>.sh`.
- Shared paths or validation: `scripts/core/`.
- Reusable Docker, Multipass, network, prompt, logging, or status behavior: `scripts/modules/`.
- Generated config, Docker, Compose, DevContainer, or cloud-init content: `scripts/generators/`.
- Dispatch and source order: `scripts/chien-dev`.
- User-visible usage: `scripts/modules/help.sh`, `README.md`, and `README.zh-TW.md`.

Read `PROJECT_STRUCTURE.md` when the change crosses layers or the correct ownership is unclear. Do not edit `templates/` expecting runtime behavior; generators do not currently consume them.

## Keep documentation current

- When a change affects functionality or architecture, update both `README.md` and `README.zh-TW.md` in the same change.
- When commands, flags, defaults, prerequisites, or examples change, also update `scripts/modules/help.sh` where applicable.
- When file ownership, module boundaries, generated artifacts, or execution flow changes, also update `PROJECT_STRUCTURE.md`.
- Keep the English and Traditional Chinese README content equivalent.

## Preserve invariants

- All sourced files share one Bash process under `set -euo pipefail`; avoid names or globals that collide across files.
- Obtain generated environment paths through helpers in `scripts/core/paths.sh`.
- Use `compose_run` for environment-scoped Compose operations.
- Preserve both DevContainer and Multipass paths unless the request explicitly excludes one.
- Keep documented flags usable without prompts.
- For deletion or irreversible cleanup, validate the exact target and backend state before prompting, default confirmation to no, then validate state again immediately before the destructive call. Treat unknown state as unsafe.

## Verify the behavior

- Add or update a shell regression test for changed branching, validation, or lifecycle behavior. Mock Docker and Multipass when the invariant can be proven without real infrastructure.
- Assert both the result and important negative side effects, such as a delete function not being called.
- Run `make verify` before handoff.
- Exercise real Docker or Multipass only when the task needs integration evidence and the dependency is available; otherwise state the unverified boundary.
