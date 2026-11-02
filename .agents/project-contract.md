# Project Contract

## Repository and authorities
- Repository: pong1013/dev-environment-setup; canonical remote: origin; default branch: main.
- Follow AGENTS.md and .agents/skills/chien-dev-cli/SKILL.md for CLI product work.
- Tracker routing: docs/agents/issue-tracker.md. Domain routing: docs/agents/domain.md.

## Architecture and compatibility
- All Bash modules share one process under set -euo pipefail; preserve source order.
- Commands: scripts/commands/; reusable operations: scripts/modules/; validation and paths: scripts/core/; rendering: scripts/generators/.
- templates/ are inactive examples. Runtime output belongs in ignored generated/.
- Preserve DevContainer and Multipass behavior, non-interactive flags, and destructive-operation safeguards.

## Verification
- Required command: make verify, matching .github/workflows/verify.yml.
- Complete verification requires Bash syntax checks, all regression tests, and repository skill validation to pass.
- scripts/verify.sh must emit HARNESS_VERIFICATION_STATUS=complete only after all checks succeed; this marker is a proposed setup-ticket change, not current behavior.
- Add regression coverage for changed behavior. Report any live Docker, Multipass, or other external integration not exercised.
- Deterministic checks alone do not establish external integration success.

## Documentation and knowledge
- Keep README.md and README.zh-TW.md equivalent for changed product behavior; update CLI help for flags/defaults and PROJECT_STRUCTURE.md for changed ownership or flow.
- Use lazy root CONTEXT.md and docs/adr/ for settled project terminology and decisions.
- Include setup/configuration and project-knowledge changes in approved issue scope before committing.

## Workspace and provenance
- Use a dedicated codex/ feature branch after Workspace Gate approval; preserve pre-existing unrelated work.
- Local checkpoints: .agents/runs/; ignore only the current run checkpoint unless broader handling is separately approved. Preserve existing unrelated checkpoint files.
- Capture exact path/hunk/hash baseline and separate staged/unstaged/untracked digests before feature writes.
- Maintain append-only mutation and ordered review-round ledgers. Validate setup receipt imports and reconcile live changes before feature review.

## Work and delivery
- Publish the approved specification as one GitHub parent issue and approved tickets as children. Mechanical setup is the first blocker ticket.
- Dispatch fresh Implementation and Quality agents concurrently for each ready ticket; review standards and specification compliance independently.
- Commit one ticket only after its checks and quality review pass.
- Require fresh full-feature review and successful reconciliation before Delivery Gate.
- Push and create the exact approved PR only after Delivery Gate approval. Attach created PRs to this chat. Never merge or directly close issues.
