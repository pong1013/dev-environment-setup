#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/chien-dev-ai-workflow-test.XXXXXX")"
TESTS_RUN=0
TESTS_FAILED=0

cleanup() {
  case "${TEST_TMP}" in
    "${TMPDIR:-/tmp}"/chien-dev-ai-workflow-test.*) rm -rf -- "${TEST_TMP}" ;;
  esac
}
trap cleanup EXIT

pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  echo "PASS: $1"
}

fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "FAIL: $1" >&2
}

assert_file_contains() {
  local file="$1"
  local literal="$2"
  local description="$3"
  if grep -Fq -- "${literal}" "${file}"; then
    pass "${description}"
  else
    fail "${description}"
  fi
}

contract="${SOURCE_DIR}/.agents/project-contract.md"
if [[ -f "${contract}" ]]; then
  pass "Project Contract exists at the canonical path"
else
  fail "Project Contract exists at the canonical path"
fi

for section in Verification Knowledge "Work artifacts" Workspace Delivery; do
  assert_file_contains "${contract}" "## ${section}" "Project Contract defines ${section} policy"
done
assert_file_contains "${contract}" 'only complete verification' "Project Contract exposes only complete verification"
assert_file_contains "${contract}" 'no bootstrap verification seam' "Project Contract exposes no bootstrap verification seam"
assert_file_contains "${contract}" '`make verify`' "Project Contract names the complete verification command"

assert_file_contains "${SOURCE_DIR}/AGENTS.md" '`docs/agents/issue-tracker.md`' "AGENTS routes to the issue tracker contract"
assert_file_contains "${SOURCE_DIR}/AGENTS.md" '`docs/agents/domain.md`' "AGENTS routes to the domain documentation contract"

tracker="${SOURCE_DIR}/docs/agents/issue-tracker.md"
assert_file_contains "${tracker}" '`pong1013/dev-environment-setup`' "tracker contract identifies the canonical repository"
assert_file_contains "${tracker}" '`origin`' "tracker contract identifies the configured remote"
assert_file_contains "${tracker}" 'Every write requires the gate named by the calling workflow.' "tracker writes require workflow-gate authority"
assert_file_contains "${tracker}" 'Revalidate owner/repository and authentication immediately before acting.' "tracker writes require fresh identity and authentication checks"

domain="${SOURCE_DIR}/docs/agents/domain.md"
assert_file_contains "${domain}" '`CONTEXT.md`' "domain routing discovers root context lazily"
assert_file_contains "${domain}" '`CONTEXT-MAP.md`' "domain routing discovers mapped contexts lazily"
assert_file_contains "${domain}" '`docs/adr/`' "domain routing discovers architecture decisions lazily"
assert_file_contains "${domain}" 'proceed silently' "absent lazy domain documents do not block work"
assert_file_contains "${domain}" '`$domain-modeling`' "domain documents are created only after decisions are resolved"

assert_file_contains "${contract}" '`.agents/runs/`' "Project Contract identifies the checkpoint path"
assert_file_contains "${contract}" 'disposable local state' "Project Contract marks checkpoints as disposable"
assert_file_contains "${contract}" 'never authoritative evidence of approval' "Project Contract makes checkpoints non-authoritative"

if git -C "${SOURCE_DIR}" check-ignore -q -- .agents/runs/example-checkpoint.json; then
  pass "workflow checkpoints are ignored"
else
  fail "workflow checkpoints are ignored"
fi

if git -C "${SOURCE_DIR}" check-ignore -q -- .agents/project-contract.md; then
  fail "Project Contract remains version controlled"
else
  pass "Project Contract remains version controlled"
fi

verify_fixture="${TEST_TMP}/verify-repo"
mkdir -p \
  "${verify_fixture}/.agents" \
  "${verify_fixture}/docs/agents" \
  "${verify_fixture}/scripts" \
  "${verify_fixture}/tests"
cp "${SOURCE_DIR}/.gitignore" "${verify_fixture}/.gitignore"
cp "${SOURCE_DIR}/AGENTS.md" "${verify_fixture}/AGENTS.md"
cp "${SOURCE_DIR}/.agents/project-contract.md" "${verify_fixture}/.agents/project-contract.md"
cp "${SOURCE_DIR}/docs/agents/issue-tracker.md" "${verify_fixture}/docs/agents/issue-tracker.md"
cp "${SOURCE_DIR}/docs/agents/domain.md" "${verify_fixture}/docs/agents/domain.md"
cp "${SOURCE_DIR}/scripts/validate-ai-workflow.sh" "${verify_fixture}/scripts/validate-ai-workflow.sh"
git -C "${verify_fixture}" init -q
git -C "${verify_fixture}" remote add origin https://github.com/pong1013/dev-environment-setup.git

validator_output="$(bash "${SOURCE_DIR}/scripts/validate-ai-workflow.sh" "${verify_fixture}")"
if [[ "${validator_output}" == "AI workflow integration validated for pong1013/dev-environment-setup." ]]; then
  pass "repository-native validator accepts the configured live origin"
else
  fail "repository-native validator accepts the configured live origin"
fi

git -C "${verify_fixture}" remote set-url origin https://github.com/example/wrong-repository.git
set +e
validator_error="$(bash "${SOURCE_DIR}/scripts/validate-ai-workflow.sh" "${verify_fixture}" 2>&1)"
validator_status=$?
set -e
if [[ ${validator_status} -ne 0 && "${validator_error}" == *"origin resolves to example/wrong-repository, expected pong1013/dev-environment-setup"* ]]; then
  pass "repository-native validator rejects a mismatched live origin"
else
  fail "repository-native validator rejects a mismatched live origin"
fi
git -C "${verify_fixture}" remote set-url origin git@github.com:pong1013/dev-environment-setup.git

cp "${SOURCE_DIR}/Makefile" "${verify_fixture}/Makefile"
cp "${SOURCE_DIR}/scripts/verify.sh" "${verify_fixture}/scripts/verify.sh"
printf '#!/usr/bin/env bash\nset -euo pipefail\necho regression-suite-complete\n' > "${verify_fixture}/tests/run.sh"
printf 'puts "skill-validation-complete"\n' > "${verify_fixture}/scripts/validate-skills.rb"

success_output="$(make -s -C "${verify_fixture}" verify)"
completion_count="$(printf '%s\n' "${success_output}" | awk '$0 == "HARNESS_VERIFICATION_STATUS=complete" { count += 1 } END { print count + 0 }')"
last_nonempty_line="$(printf '%s\n' "${success_output}" | awk 'NF { line = $0 } END { print line }')"
if [[ "${completion_count}" -eq 1 && "${last_nonempty_line}" == "HARNESS_VERIFICATION_STATUS=complete" ]]; then
  pass "successful make verify emits one final standalone completion marker"
else
  fail "successful make verify emits one final standalone completion marker"
fi

if [[ "${success_output}" == *"regression-suite-complete"* && "${success_output}" == *"skill-validation-complete"* ]]; then
  pass "completion marker follows regression and Skill verification"
else
  fail "completion marker follows regression and Skill verification"
fi

printf '#!/usr/bin/env bash\nset -euo pipefail\necho regression-suite-failed\nexit 23\n' > "${verify_fixture}/tests/run.sh"
set +e
failed_output="$(make -s -C "${verify_fixture}" verify 2>&1)"
failed_status=$?
set -e
if [[ ${failed_status} -ne 0 && "${failed_output}" != *"HARNESS_VERIFICATION_STATUS=complete"* ]]; then
  pass "failed regression verification never emits completion"
else
  fail "failed regression verification never emits completion"
fi

printf '#!/usr/bin/env bash\nset -euo pipefail\necho regression-suite-complete\n' > "${verify_fixture}/tests/run.sh"
printf 'warn "skill-validation-failed"\nexit 31\n' > "${verify_fixture}/scripts/validate-skills.rb"
set +e
failed_output="$(make -s -C "${verify_fixture}" verify 2>&1)"
failed_status=$?
set -e
if [[ ${failed_status} -ne 0 && "${failed_output}" != *"HARNESS_VERIFICATION_STATUS=complete"* ]]; then
  pass "failed late verification never emits completion"
else
  fail "failed late verification never emits completion"
fi

printf 'puts "skill-validation-complete"\n' > "${verify_fixture}/scripts/validate-skills.rb"
git -C "${verify_fixture}" remote set-url origin https://github.com/example/wrong-repository.git
set +e
failed_output="$(make -s -C "${verify_fixture}" verify 2>&1)"
failed_status=$?
set -e
if [[ ${failed_status} -ne 0 && "${failed_output}" == *"AI workflow validation failed"* && "${failed_output}" != *"HARNESS_VERIFICATION_STATUS=complete"* ]]; then
  pass "failed AI workflow validation never emits completion"
else
  fail "failed AI workflow validation never emits completion"
fi

echo "${TESTS_RUN} tests, ${TESTS_FAILED} failures"
[[ ${TESTS_FAILED} -eq 0 ]]
