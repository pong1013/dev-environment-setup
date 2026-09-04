#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/chien-dev-harness-audit-test.XXXXXX")"
TESTS_RUN=0
TESTS_FAILED=0

cleanup() {
  case "${TEST_TMP}" in
    "${TMPDIR:-/tmp}"/chien-dev-harness-audit-test.*) rm -rf -- "${TEST_TMP}" ;;
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

repo="${TEST_TMP}/repo"
mkdir -p "${repo}/scripts" "${repo}/generated"
git -C "${repo}" init -q
printf '.env\ngenerated/\n' > "${repo}/.gitignore"
printf '# baseline\n' > "${repo}/AGENTS.md"
printf '#!/usr/bin/env bash\necho baseline\n' > "${repo}/scripts/example.sh"
git -C "${repo}" add .gitignore AGENTS.md scripts/example.sh
git -C "${repo}" -c user.name=test -c user.email=test@example.com commit -qm baseline

printf '#!/usr/bin/env bash\nAPI_KEY=supersecret\nDATABASE_URL=postgres://audit_user:db-password@db.example.test:5432/app\ncurl -H "Authorization: Basic YXVkaXRfdXNlcjpiYXNpYy1wYXNzd29yZA=="\necho safe-change\necho ghp_12345678901234567890\n-----BEGIN PRIVATE KEY-----\n' > "${repo}/scripts/example.sh"
printf 'TOP_SECRET=hidden\n' > "${repo}/.env"
printf 'credential-value\n' > "${repo}/credentials.txt"
printf 'ignored-value\n' > "${repo}/generated/runtime.txt"

if HARNESS_AUDIT_ROOT="${repo}" bash "${SOURCE_DIR}/scripts/harness-audit.sh" --print-input >/dev/null 2>"${TEST_TMP}/untrusted.err"; then
  fail "audit requires explicit trusted confirmation"
elif grep -q 'not a confidentiality boundary' "${TEST_TMP}/untrusted.err"; then
  pass "audit requires explicit trusted confirmation"
else
  fail "audit explains the read-only confidentiality limitation"
fi

audit_output="$(HARNESS_AUDIT_ROOT="${repo}" bash "${SOURCE_DIR}/scripts/harness-audit.sh" --trusted --print-input)"

if [[ "${audit_output}" == *"--- FILE: scripts/example.sh ---"* && "${audit_output}" == *"safe-change"* ]]; then
  pass "allowlisted changed source is included"
else
  fail "allowlisted changed source is included"
fi

if [[ "${audit_output}" == *"[REDACTED SECRET-LIKE LINE]"* && "${audit_output}" != *"supersecret"* && "${audit_output}" != *"audit_user"* && "${audit_output}" != *"db-password"* && "${audit_output}" != *"YXVkaXRfdXNlcjpiYXNpYy1wYXNzd29yZA=="* && "${audit_output}" != *"ghp_12345678901234567890"* && "${audit_output}" != *"BEGIN PRIVATE KEY"* ]]; then
  pass "secret-like source lines, URLs, and Basic Auth are redacted"
else
  fail "secret-like source lines, URLs, and Basic Auth are redacted"
fi

if [[ "${audit_output}" != *"TOP_SECRET"* && "${audit_output}" != *"hidden"* && "${audit_output}" != *"credential-value"* ]]; then
  pass "secret-like and ignored untracked files are excluded"
else
  fail "secret-like and ignored untracked files are excluded"
fi

if [[ "${audit_output}" != *"ignored-value"* && "${audit_output}" != *"runtime.txt"* ]]; then
  pass "generated files are excluded"
else
  fail "generated files are excluded"
fi

echo "${TESTS_RUN} tests, ${TESTS_FAILED} failures"
[[ ${TESTS_FAILED} -eq 0 ]]
