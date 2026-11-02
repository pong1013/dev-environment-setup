#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EXPECTED_REPOSITORY="pong1013/dev-environment-setup"

fail() {
  echo "AI workflow validation failed: $1" >&2
  exit 1
}

require_regular_file() {
  local relative_path="$1"

  [[ -f "${ROOT_DIR}/${relative_path}" && ! -L "${ROOT_DIR}/${relative_path}" ]] ||
    fail "required control file is missing or is a symlink: ${relative_path}"
}

require_literal() {
  local relative_path="$1"
  local literal="$2"
  local description="$3"

  grep -Fq -- "${literal}" "${ROOT_DIR}/${relative_path}" || fail "${description}"
}

github_repository_from_remote() {
  local remote_url="$1"
  local repository

  case "${remote_url}" in
    https://github.com/*)
      repository="${remote_url#https://github.com/}"
      ;;
    git@github.com:*)
      repository="${remote_url#git@github.com:}"
      ;;
    ssh://git@github.com/*)
      repository="${remote_url#ssh://git@github.com/}"
      ;;
    *)
      fail "origin is not a supported GitHub URL: ${remote_url}"
      ;;
  esac

  repository="${repository%/}"
  repository="${repository%.git}"
  printf '%s\n' "${repository}"
}

git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  fail "repository root is not a Git working tree: ${ROOT_DIR}"

origin_url="$(git -C "${ROOT_DIR}" remote get-url origin 2>/dev/null)" ||
  fail "Git remote origin is not configured"
actual_repository="$(github_repository_from_remote "${origin_url}")"
[[ "${actual_repository}" == "${EXPECTED_REPOSITORY}" ]] ||
  fail "origin resolves to ${actual_repository}, expected ${EXPECTED_REPOSITORY}"

required_files=(
  AGENTS.md
  .agents/project-contract.md
  docs/agents/issue-tracker.md
  docs/agents/domain.md
)
for relative_path in "${required_files[@]}"; do
  require_regular_file "${relative_path}"
done

for section in Verification Knowledge "Work artifacts" Workspace Delivery; do
  require_literal .agents/project-contract.md "## ${section}" "Project Contract is missing the ${section} section"
done
require_literal .agents/project-contract.md '`make verify`' "Project Contract does not name the complete verification command"
require_literal .agents/project-contract.md 'HARNESS_VERIFICATION_STATUS=complete' "Project Contract does not define the completion marker"
require_literal .agents/project-contract.md '`docs/agents/issue-tracker.md`' "Project Contract does not route issue tracker knowledge"
require_literal .agents/project-contract.md '`docs/agents/domain.md`' "Project Contract does not route domain knowledge"
require_literal .agents/project-contract.md '`.agents/runs/`' "Project Contract does not define workflow checkpoint policy"
require_literal .agents/project-contract.md 'disposable' "Project Contract does not describe workflow checkpoints as disposable"
require_literal .agents/project-contract.md 'never authoritative' "Project Contract does not describe workflow checkpoints as non-authoritative"

require_literal AGENTS.md '`docs/agents/issue-tracker.md`' "AGENTS.md does not route to the issue tracker contract"
require_literal AGENTS.md '`docs/agents/domain.md`' "AGENTS.md does not route to the domain documentation contract"

require_literal docs/agents/issue-tracker.md "**Repository:** \`${EXPECTED_REPOSITORY}\`" "issue tracker contract names the wrong repository"
require_literal docs/agents/issue-tracker.md '**Configured from remote:** `origin`' "issue tracker contract does not name origin"
require_literal docs/agents/domain.md '`CONTEXT.md`' "domain routing does not define lazy domain documentation"
require_literal docs/agents/domain.md 'proceed silently' "domain routing does not preserve lazy discovery"

git -C "${ROOT_DIR}" check-ignore -q -- .agents/runs/validation-checkpoint.json ||
  fail ".agents/runs/ is not ignored"
if git -C "${ROOT_DIR}" check-ignore -q -- .agents/project-contract.md; then
  fail ".agents/project-contract.md must remain version controlled"
fi

echo "AI workflow integration validated for ${EXPECTED_REPOSITORY}."
