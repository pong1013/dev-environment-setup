#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TESTS_RUN=0
TESTS_FAILED=0

pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  echo "PASS: $1"
}

fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "FAIL: $1" >&2
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local description="$3"

  if grep -Eq -- "${pattern}" "${file}"; then
    pass "${description}"
  else
    fail "${description}"
  fi
}

assert_section_contains() {
  local file="$1"
  local heading="$2"
  local pattern="$3"
  local description="$4"
  local section

  section="$(awk -v heading="${heading}" '
    $0 == heading { in_section = 1; next }
    in_section && /^### / { exit }
    in_section { print }
  ' "${file}")"

  if grep -Eq -- "${pattern}" <<< "${section}"; then
    pass "${description}"
  else
    fail "${description}"
  fi
}

assert_not_full_workflow_copy() {
  local file="$1"
  local description="$2"
  local normalized

  normalized="$(tr '[:upper:]' '[:lower:]' < "${file}")"
  if [[ "${normalized}" == *"preflight"* &&
        "${normalized}" == *"grill"* &&
        "${normalized}" == *"specification gate"* &&
        "${normalized}" == *"ticket breakdown gate"* &&
        "${normalized}" == *"delivery gate"* ]]; then
    fail "${description}"
  else
    pass "${description}"
  fi
}

english_readme="${ROOT_DIR}/README.md"
chinese_readme="${ROOT_DIR}/README.zh-TW.md"
structure_guide="${ROOT_DIR}/PROJECT_STRUCTURE.md"

assert_contains "${english_readme}" '!\[[^]]*[Dd]evelopment [Hh]arness[^]]*\]\(\.?/assets/harness\.png\)|<img[^>]+src="\.?/assets/harness\.png"[^>]*>' \
  "English README displays the development harness diagram"
assert_contains "${english_readme}" '[Dd]evelopment [Hh]arness (architecture|architecture diagram)' \
  "English README scopes the diagram to the development harness architecture"
assert_contains "${english_readme}" '\]\(https://github\.com/pong1013/ai-workflow\)' \
  "English README links to the exact ai-workflow repository"
assert_not_full_workflow_copy "${english_readme}" \
  "English README refers upstream instead of reproducing the full workflow"

assert_contains "${chinese_readme}" '!\[[^]]*(開發|[Dd]evelopment)[^]]*[Hh]arness[^]]*\]\(\.?/assets/harness\.png\)|<img[^>]+src="\.?/assets/harness\.png"[^>]*>' \
  "Traditional Chinese README displays the development harness diagram"
assert_contains "${chinese_readme}" '(開發 ?[Hh]arness|development harness).*(架構|architecture)' \
  "Traditional Chinese README scopes the diagram to the development harness architecture"
assert_contains "${chinese_readme}" '\]\(https://github\.com/pong1013/ai-workflow\)' \
  "Traditional Chinese README links to the exact ai-workflow repository"
assert_not_full_workflow_copy "${chinese_readme}" \
  "Traditional Chinese README refers upstream instead of reproducing the full workflow"

for documented_path in \
  '.agents/project-contract.md' \
  'docs/agents/issue-tracker.md' \
  'docs/agents/domain.md' \
  '.agents/runs/' \
  'assets/harness.png'; do
  assert_contains "${structure_guide}" "${documented_path//./\\.}" \
    "Project structure guide documents ${documented_path}"
done

assert_section_contains "${structure_guide}" '### `.agents/runs/`' '(拋棄|丟棄|暫存|disposable).*(非權威|不具權威|non-authoritative)' \
  "Project structure guide marks checkpoints disposable and non-authoritative"
assert_section_contains "${structure_guide}" '### `assets/harness.png`' '(開發 ?[Hh]arness|development harness).*(架構|architecture)' \
  "Project structure guide scopes the diagram to the development harness architecture"

echo "${TESTS_RUN} tests, ${TESTS_FAILED} failures"
[[ ${TESTS_FAILED} -eq 0 ]]
