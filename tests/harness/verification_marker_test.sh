#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/chien-dev-verification-marker-test.XXXXXX")"

cleanup() {
  case "${TEST_TMP}" in
    "${TMPDIR:-/tmp}"/chien-dev-verification-marker-test.*) rm -rf -- "${TEST_TMP}" ;;
  esac
}
trap cleanup EXIT

# Run the real verification entry point, runner and validator in a small repository.
# The fixture suite avoids recursively running this acceptance test.
repo="${TEST_TMP}/repo"
mkdir -p "${repo}/scripts" "${repo}/tests" "${repo}/.agents"
cp "${SOURCE_DIR}/scripts/verify.sh" "${SOURCE_DIR}/scripts/validate-skills.rb" "${repo}/scripts/"
cp "${SOURCE_DIR}/tests/run.sh" "${repo}/tests/"
cp -R "${SOURCE_DIR}/.agents/skills" "${repo}/.agents/skills"
printf '#!/usr/bin/env bash\nexit 0\n' > "${repo}/tests/fixture_test.sh"

bash "${repo}/scripts/verify.sh" > "${TEST_TMP}/success.log" 2>&1
if [[ "$(tail -n 1 "${TEST_TMP}/success.log")" != 'HARNESS_VERIFICATION_STATUS=complete' ]]; then
  echo 'FAIL: successful verification ends with its completion marker' >&2
  cat "${TEST_TMP}/success.log" >&2
  exit 1
fi
echo 'PASS: successful verification ends with its completion marker'

printf '#!/usr/bin/env bash\necho "controlled regression failure" >&2\nexit 17\n' > "${repo}/tests/fixture_test.sh"
if bash "${repo}/scripts/verify.sh" > "${TEST_TMP}/failure.log" 2>&1; then
  echo 'FAIL: failed regression must make verification fail' >&2
  exit 1
fi
if grep -Fxq 'HARNESS_VERIFICATION_STATUS=complete' "${TEST_TMP}/failure.log"; then
  echo 'FAIL: failed verification must not emit a completion marker' >&2
  exit 1
fi
if ! grep -Fxq 'controlled regression failure' "${TEST_TMP}/failure.log"; then
  echo 'FAIL: verification must reach the controlled failing regression' >&2
  cat "${TEST_TMP}/failure.log" >&2
  exit 1
fi
echo 'PASS: failed regression stops verification without a completion marker'
