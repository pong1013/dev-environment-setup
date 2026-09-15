# Project Contract

## Verification

- Status: `complete`
- Verification seam: this repository exposes only complete verification; it has no bootstrap verification seam.
- Complete verification command: `make verify`
- Success contract: after every deterministic check succeeds, verification emits the exact standalone stdout line `HARNESS_VERIFICATION_STATUS=complete`.
- Failure contract: verification exits non-zero without emitting the completion status when any check fails.
- Project checks: `scripts/verify.sh`, `tests/run.sh`, `scripts/validate-skills.rb`, `scripts/validate-ai-workflow.sh`, `.github/workflows/verify.yml`
- External limitation: Docker and Multipass integration are not exercised by the deterministic suite and must be disclosed when untested.

## Knowledge

- Repository instructions: `AGENTS.md`
- Issue tracker routing: `docs/agents/issue-tracker.md`
- Domain documentation routing: `docs/agents/domain.md`
- Domain language: `CONTEXT.md` (lazy; currently absent)
- Architecture decisions: `docs/adr/` (lazy; currently absent)

## Work artifacts

- Specifications: GitHub parent issues in `pong1013/dev-environment-setup`
- Ticket backend: GitHub Issues with sub-issues and dependency relationships

## Workspace

- Default branch: `main`
- Feature branch naming: `codex/<feature-slug>`
- Preserve unrelated working-tree changes: yes
- Workflow checkpoints: `.agents/runs/` is ignored, disposable local state and is never authoritative evidence of approval.

## Delivery

- Mode: `pull-request`
- Remote and target branch: `origin/main`
- Require Delivery Gate: yes
