#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL_URL="https://github.com/pong1013/dev-environment-setup.git"
TESTS_RUN=0
TESTS_FAILED=0

fail() {
  echo "FAIL: $*" >&2
  return 1
}

run_test() {
  local name="$1"
  shift
  TESTS_RUN=$((TESTS_RUN + 1))
  if ("$@"); then
    echo "PASS: ${name}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "FAIL: ${name}" >&2
  fi
}

setup_fixture() {
  fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/chien-dev-update-integration.XXXXXX")" || return 1
  trap '[[ -n "${fixture_dir:-}" && "${fixture_dir}" == *"/chien-dev-update-integration."* ]] && rm -rf -- "${fixture_dir}"' EXIT
  install_dir="${fixture_dir}/install"
  remote_dir="${fixture_dir}/remote.git"
  upstream_dir="${fixture_dir}/upstream"
  output_file="${fixture_dir}/output"
  shim_dir="${fixture_dir}/shim"
  cli_remote_dir="${remote_dir}"
  real_git="$(command -v git)"
  mkdir -p "${install_dir}"
  cp -R "${SOURCE_DIR}/scripts" "${install_dir}/scripts"
  printf 'base\n' > "${install_dir}/VERSION_TEST"

  git init -q -b main "${install_dir}"
  git -C "${install_dir}" config user.name 'Update Integration Test'
  git -C "${install_dir}" config user.email 'update-test@example.invalid'
  git -C "${install_dir}" add scripts VERSION_TEST
  git -C "${install_dir}" commit -qm 'base install'
  base_sha="$(git -C "${install_dir}" rev-parse HEAD)"

  git init -q --bare "${remote_dir}"
  git -C "${install_dir}" remote add origin "${CANONICAL_URL}"
  export GIT_CONFIG_GLOBAL="${fixture_dir}/gitconfig"
  export GIT_CONFIG_NOSYSTEM=1
  : > "${GIT_CONFIG_GLOBAL}"
  git -C "${install_dir}" push -q "${remote_dir}" main:main
  git clone -q -b main "file://${remote_dir}" "${upstream_dir}"
  git -C "${upstream_dir}" config user.name 'Update Integration Test'
  git -C "${upstream_dir}" config user.email 'update-test@example.invalid'

  mkdir -p "${shim_dir}"
  cat > "${shim_dir}/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

operation=""
for argument in "$@"; do
  case "${argument}" in
    ls-remote|fetch) operation="${argument}" ;;
  esac
done

arguments=()
for argument in "$@"; do
  if [[ "${operation}" == "ls-remote" || "${operation}" == "fetch" ]] &&
     [[ "${argument}" == "${UPDATE_TEST_CANONICAL_URL}" ]]; then
    arguments+=("${UPDATE_TEST_REMOTE_URL}")
  else
    arguments+=("${argument}")
  fi
done
exec "${UPDATE_TEST_REAL_GIT}" "${arguments[@]}"
SH
  chmod +x "${shim_dir}/git"
}

advance_remote() {
  local marker="$1"
  printf '%s\n' "${marker}" > "${upstream_dir}/VERSION_TEST"
  git -C "${upstream_dir}" add VERSION_TEST
  git -C "${upstream_dir}" commit -qm "remote ${marker}"
  git -C "${upstream_dir}" push -q origin main
  latest_sha="$(git -C "${upstream_dir}" rev-parse HEAD)"
}

run_noninteractive() {
  if UPDATE_TEST_REAL_GIT="${real_git}" UPDATE_TEST_REMOTE_URL="file://${cli_remote_dir}" UPDATE_TEST_CANONICAL_URL="${CANONICAL_URL}" PATH="${shim_dir}:${PATH}" \
      "${install_dir}/scripts/chien-dev" update </dev/null >"${output_file}" 2>&1; then
    update_status=0
  else
    update_status=$?
  fi
}

run_interactive() {
  local answer="$1"
  local mutation="${2:-none}"
  local prompt_policy="${3:-required}"
  if UPDATE_TEST_REAL_GIT="${real_git}" UPDATE_TEST_REMOTE_URL="file://${cli_remote_dir}" UPDATE_TEST_CANONICAL_URL="${CANONICAL_URL}" PATH="${shim_dir}:${PATH}" \
      python3 - "${install_dir}/scripts/chien-dev" "${answer}" "${mutation}" "${install_dir}" "${upstream_dir}" "${prompt_policy}" >"${output_file}" 2>&1 <<'PY'
import errno
import os
import pty
import re
import select
import signal
import subprocess
import sys
import time
from pathlib import Path

executable, answer, mutation, install, upstream, prompt_policy = sys.argv[1:]
pid, fd = pty.fork()
if pid == 0:
    os.execv(executable, [executable, "update"])

prompt_seen = False
deadline = time.monotonic() + 15
captured = bytearray()
while time.monotonic() < deadline:
    ready, _, _ = select.select([fd], [], [], 0.2)
    if not ready:
        continue
    try:
        chunk = os.read(fd, 65536)
    except OSError as error:
        if error.errno == errno.EIO:
            break
        raise
    if not chunk:
        break
    captured.extend(chunk)
    sys.stdout.buffer.write(chunk)
    sys.stdout.buffer.flush()
    if not prompt_seen and re.search(rb"\[[Yy]/[Nn]\]|\[[Nn]/[Yy]\]", captured):
        prompt_seen = True
        if mutation == "dirty":
            Path(install, "changed-during-confirmation").write_text("local change\n")
        elif mutation == "remote":
            Path(upstream, "VERSION_TEST").write_text("changed-during-confirmation\n")
            subprocess.run(["git", "-C", upstream, "add", "VERSION_TEST"], check=True)
            subprocess.run(["git", "-C", upstream, "commit", "-qm", "remote changed during confirmation"], check=True)
            subprocess.run(["git", "-C", upstream, "push", "-q", "origin", "main"], check=True)
        os.write(fd, b"\x04" if answer == "EOF" else (answer + "\n").encode())
else:
    os.kill(pid, signal.SIGTERM)
    os.waitpid(pid, 0)
    sys.exit(98)

_, status = os.waitpid(pid, 0)
if not prompt_seen and prompt_policy == "required":
    sys.exit(97)
sys.exit(os.waitstatus_to_exitcode(status))
PY
  then
    update_status=0
  else
    update_status=$?
  fi
}

assert_head_and_content() {
  local expected_sha="$1"
  local expected_content="$2"
  [[ "$(git -C "${install_dir}" rev-parse HEAD)" == "${expected_sha}" ]] || { fail "installation HEAD changed unexpectedly"; return 1; }
  [[ "$(<"${install_dir}/VERSION_TEST")" == "${expected_content}" ]] || fail "installation content changed unexpectedly"
}

assert_nonzero() {
  [[ "${update_status}" -ne 0 ]] || { fail "expected a nonzero update status"; return 1; }
  [[ "${update_status}" -ne 97 && "${update_status}" -ne 98 ]] || fail "CLI prompt was missing or timed out in the test harness"
}

assert_zero() {
  [[ "${update_status}" -eq 0 ]] || fail "expected update status 0, got ${update_status}: $(<"${output_file}")"
}

assert_no_prompt() {
  ! grep -Eiq '\[[Yy]/[Nn]\]|\[[Nn]/[Yy]\]' "${output_file}" || fail "unexpected confirmation prompt"
}

assert_not_reported_behind() {
  ! grep -Eiq 'behind' "${output_file}" || fail "non-fast-forward checkout was incorrectly reported as behind"
}

test_current_installation() {
  setup_fixture || return
  run_noninteractive
  assert_zero || return
  assert_head_and_content "${base_sha}" base || return
  assert_no_prompt || return
  grep -Fq "${base_sha:0:7}" "${output_file}" || fail "current commit is not reported"
}

test_confirmed_update() {
  setup_fixture || return
  advance_remote latest || return
  run_interactive y
  assert_zero || return
  assert_head_and_content "${latest_sha}" latest || return
  grep -Fq "${base_sha:0:7}" "${output_file}" || { fail "installed commit is not reported"; return; }
  grep -Fq "${latest_sha:0:7}" "${output_file}" || fail "GitHub commit is not reported"
}

test_declined_update() {
  setup_fixture || return
  advance_remote latest || return
  run_interactive n
  assert_zero || return
  assert_head_and_content "${base_sha}" base || return
  grep -Eiq 'behind|declin|not updat|remain' "${output_file}" || fail "decline did not report the installation remains behind"
}

test_noninteractive_refusal() {
  setup_fixture || return
  advance_remote latest || return
  run_noninteractive
  assert_nonzero || return
  assert_head_and_content "${base_sha}" base || return
  assert_no_prompt
}

test_unavailable_remote() {
  setup_fixture || return
  advance_remote latest || return
  cli_remote_dir="${fixture_dir}/missing.git"
  run_noninteractive
  assert_nonzero || return
  assert_head_and_content "${base_sha}" base || return
  assert_no_prompt
}

test_rewritten_canonical_url() {
  setup_fixture || return
  git config --file "${GIT_CONFIG_GLOBAL}" "url.file://${remote_dir}.insteadOf" "${CANONICAL_URL}"
  [[ "$(git -C "${install_dir}" remote get-url origin)" == "file://${remote_dir}" ]] || { fail "fixture did not rewrite effective origin URL"; return; }
  run_noninteractive
  assert_nonzero || return
  assert_head_and_content "${base_sha}" base || return
  assert_no_prompt
}

test_non_git_executable() {
  setup_fixture || return
  mkdir -p "${fixture_dir}/outside"
  cp -R "${SOURCE_DIR}/scripts" "${fixture_dir}/outside/scripts"
  if "${fixture_dir}/outside/scripts/chien-dev" update </dev/null >"${output_file}" 2>&1; then
    update_status=0
  else
    update_status=$?
  fi
  assert_nonzero || return
  [[ -d "${fixture_dir}/outside/scripts" ]] || { fail "non-Git executable disappeared"; return; }
  assert_no_prompt
}

test_unrelated_remote() {
  setup_fixture || return
  advance_remote latest || return
  git -C "${install_dir}" remote set-url origin "file://${remote_dir}"
  run_interactive y none optional
  assert_nonzero || return
  assert_head_and_content "${base_sha}" base || return
  assert_no_prompt
}

test_dirty_checkout() {
  setup_fixture || return
  advance_remote latest || return
  printf 'local work\n' > "${install_dir}/local-change"
  run_interactive y none optional
  assert_nonzero || return
  assert_head_and_content "${base_sha}" base || return
  [[ "$(<"${install_dir}/local-change")" == 'local work' ]] || { fail "local change was discarded"; return; }
  assert_no_prompt
}

test_wrong_branch() {
  setup_fixture || return
  advance_remote latest || return
  git -C "${install_dir}" switch -q -c feature
  run_interactive y none optional
  assert_nonzero || return
  assert_head_and_content "${base_sha}" base || return
  [[ "$(git -C "${install_dir}" branch --show-current)" == feature ]] || { fail "branch changed unexpectedly"; return; }
  assert_no_prompt
}

test_diverged_checkout() {
  setup_fixture || return
  advance_remote latest || return
  printf 'local commit\n' > "${install_dir}/local-commit"
  git -C "${install_dir}" add local-commit
  git -C "${install_dir}" commit -qm 'local divergence'
  local diverged_sha
  diverged_sha="$(git -C "${install_dir}" rev-parse HEAD)"
  run_interactive y none optional
  assert_nonzero || return
  assert_head_and_content "${diverged_sha}" base || return
  [[ "$(<"${install_dir}/local-commit")" == 'local commit' ]] || { fail "local commit was discarded"; return; }
  assert_no_prompt || return
  assert_not_reported_behind
}

test_ahead_checkout() {
  setup_fixture || return
  printf 'local commit\n' > "${install_dir}/local-commit"
  git -C "${install_dir}" add local-commit
  git -C "${install_dir}" commit -qm 'local ahead commit'
  local ahead_sha
  ahead_sha="$(git -C "${install_dir}" rev-parse HEAD)"
  run_interactive y none optional
  assert_nonzero || return
  assert_head_and_content "${ahead_sha}" base || return
  [[ "$(<"${install_dir}/local-commit")" == 'local commit' ]] || { fail "local commit was discarded"; return; }
  assert_no_prompt || return
  assert_not_reported_behind
}

test_dirty_after_confirmation() {
  setup_fixture || return
  advance_remote latest || return
  run_interactive y dirty
  assert_nonzero || return
  assert_head_and_content "${base_sha}" base || return
  [[ -f "${install_dir}/changed-during-confirmation" ]] || fail "test mutation was not applied"
}

test_target_changed_after_confirmation() {
  setup_fixture || return
  advance_remote latest || return
  run_interactive y remote
  assert_nonzero || return
  assert_head_and_content "${base_sha}" base || return
  [[ "$(git -C "${upstream_dir}" rev-parse HEAD)" != "${latest_sha}" ]] || fail "test remote mutation was not applied"
}

test_confirmation_input_eof() {
  setup_fixture || return
  advance_remote latest || return
  run_interactive EOF
  assert_nonzero || return
  assert_head_and_content "${base_sha}" base || return
  ! grep -Eiq 'update declined' "${output_file}" || fail "prompt EOF was treated as an ordinary decline"
}

run_test 'current installation reports its commit without prompting' test_current_installation
run_test 'confirmed update fast-forwards installation' test_confirmed_update
run_test 'declined update leaves installation behind' test_declined_update
run_test 'noninteractive update is refused' test_noninteractive_refusal
run_test 'unavailable remote is refused' test_unavailable_remote
run_test 'Git URL rewrite away from canonical repository is refused' test_rewritten_canonical_url
run_test 'non-Git executable is refused' test_non_git_executable
run_test 'unrelated remote is refused' test_unrelated_remote
run_test 'dirty checkout is refused' test_dirty_checkout
run_test 'wrong branch is refused' test_wrong_branch
run_test 'diverged checkout is refused' test_diverged_checkout
run_test 'ahead checkout is refused without a false behind report' test_ahead_checkout
run_test 'checkout changed during confirmation is refused' test_dirty_after_confirmation
run_test 'remote target changed during confirmation is refused' test_target_changed_after_confirmation
run_test 'confirmation input EOF is refused rather than declined' test_confirmation_input_eof

echo "${TESTS_RUN} tests, ${TESTS_FAILED} failures"
[[ "${TESTS_FAILED}" -eq 0 ]]
