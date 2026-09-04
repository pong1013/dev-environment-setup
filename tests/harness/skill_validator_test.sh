#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATOR="${SOURCE_DIR}/scripts/validate-skills.rb"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/chien-dev-skill-validator-test.XXXXXX")"
TESTS_RUN=0
TESTS_FAILED=0

cleanup() {
  case "${TEST_TMP}" in
    "${TMPDIR:-/tmp}"/chien-dev-skill-validator-test.*) rm -rf -- "${TEST_TMP}" ;;
  esac
}
trap cleanup EXIT

write_valid_skill() {
  local root="$1"
  mkdir -p "${root}/demo/agents"
  printf '%s\n' \
    '---' \
    'name: demo' \
    'description: Validate a realistic repository skill.' \
    '---' \
    '' \
    '# Demo' > "${root}/demo/SKILL.md"
  printf '%s\n' \
    'interface:' \
    '  display_name: "Demo Skill"' \
    '  short_description: "Validate a realistic demo skill"' \
    '  default_prompt: "Use $demo to validate this example."' > "${root}/demo/agents/openai.yaml"
}

assert_accepts() {
  local name="$1"
  local root="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if ruby "${VALIDATOR}" "${root}" >/dev/null 2>&1; then
    echo "PASS: ${name}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "FAIL: ${name}" >&2
  fi
}

assert_rejects() {
  local name="$1"
  local root="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if ruby "${VALIDATOR}" "${root}" >/dev/null 2>&1; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "FAIL: ${name}" >&2
  else
    echo "PASS: ${name}"
  fi
}

valid_root="${TEST_TMP}/valid"
write_valid_skill "${valid_root}"
assert_accepts "valid skill" "${valid_root}"

malformed_root="${TEST_TMP}/malformed"
write_valid_skill "${malformed_root}"
printf '%s\n' '---' 'name: demo' 'description: [broken' '---' '# Demo' > "${malformed_root}/demo/SKILL.md"
assert_rejects "malformed YAML" "${malformed_root}"

wrong_type_root="${TEST_TMP}/wrong-type"
write_valid_skill "${wrong_type_root}"
printf '%s\n' '---' 'name: demo' 'description: [not, a, string]' '---' '# Demo' > "${wrong_type_root}/demo/SKILL.md"
assert_rejects "wrong description type" "${wrong_type_root}"

unknown_key_root="${TEST_TMP}/unknown-key"
write_valid_skill "${unknown_key_root}"
printf '%s\n' '---' 'name: demo' 'description: Validate a realistic repository skill.' 'unexpected: true' '---' '# Demo' > "${unknown_key_root}/demo/SKILL.md"
assert_rejects "unknown frontmatter key" "${unknown_key_root}"

duplicate_key_root="${TEST_TMP}/duplicate-key"
write_valid_skill "${duplicate_key_root}"
printf '%s\n' '---' 'name: demo' 'name: duplicate' 'description: Validate a realistic repository skill.' '---' '# Demo' > "${duplicate_key_root}/demo/SKILL.md"
assert_rejects "duplicate YAML key" "${duplicate_key_root}"

bad_interface_root="${TEST_TMP}/bad-interface"
write_valid_skill "${bad_interface_root}"
printf '%s\n' 'interface: []' > "${bad_interface_root}/demo/agents/openai.yaml"
assert_rejects "invalid openai.yaml interface" "${bad_interface_root}"

stale_prompt_root="${TEST_TMP}/stale-prompt"
write_valid_skill "${stale_prompt_root}"
printf '%s\n' \
  'interface:' \
  '  display_name: "Demo Skill"' \
  '  short_description: "Validate a realistic demo skill"' \
  '  default_prompt: "Use $other to validate this example."' > "${stale_prompt_root}/demo/agents/openai.yaml"
assert_rejects "openai.yaml prompt references its skill" "${stale_prompt_root}"

echo "${TESTS_RUN} tests, ${TESTS_FAILED} failures"
[[ ${TESTS_FAILED} -eq 0 ]]

