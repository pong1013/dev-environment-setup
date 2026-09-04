#!/usr/bin/env bash

set -uo pipefail

TESTS_RUN=0
TESTS_FAILED=0

fail() {
  echo "FAIL: $*" >&2
  return 1
}

assert_dir_exists() {
  [[ -d "$1" ]] || fail "expected directory to exist: $1"
}

assert_dir_missing() {
  [[ ! -d "$1" ]] || fail "expected directory to be removed: $1"
}

run_test() {
  local name="$1"
  shift
  TESTS_RUN=$((TESTS_RUN + 1))

  if ("$@"); then
    echo "PASS: ${name}"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

setup_mocks() {
  test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/chien-dev-clean-test.XXXXXX")" || {
    fail "could not create the test temporary directory"
    return 1
  }
  trap '[[ -n "${test_tmp:-}" && "${test_tmp}" == *"/chien-dev-clean-test."* ]] && rm -rf -- "${test_tmp}"' EXIT
  mkdir -p "${test_tmp}/env" || {
    fail "could not create the test environment directory"
    return 1
  }

  validate_env_name() { :; }
  env_dir_for() { echo "${test_tmp}/env"; }
  config_file_for() { echo "${test_tmp}/env/chien-dev.yaml"; }
  compose_file_for() { echo "${test_tmp}/env/docker-compose.yml"; }
  log_info() { :; }
  log_warn() { :; }
  log_error() { last_error="$*"; }
  log_success() { :; }
  prompt_yes_no() { prompt_called="true"; return 0; }
  multipass() { :; }
  vm_exists() { return 1; }
  vm_get_status() { echo "Stopped"; }
  vm_delete() { vm_deleted="true"; }
  ensure_dependencies() { :; }
  compose_project_is_running() { return 1; }
  compose_run() { compose_called="true"; }

  prompt_called="false"
  vm_deleted="false"
  compose_called="false"
  last_error=""
}

test_running_devcontainer_is_refused() {
  setup_mocks || return
  printf 'backend: devcontainer\n' > "${test_tmp}/env/chien-dev.yaml"
  touch "${test_tmp}/env/docker-compose.yml"
  compose_project_is_running() { return 0; }

  if do_clean demo; then
    fail "clean unexpectedly succeeded for a running DevContainer"
    return
  fi

  assert_dir_exists "${test_tmp}/env" || return
  [[ "${prompt_called}" == "false" ]] || fail "confirmation should not run before the status guard"
  [[ "${compose_called}" == "false" ]] || fail "Compose cleanup should not run"
}

test_stopped_devcontainer_is_cleaned() {
  setup_mocks || return
  printf 'backend: devcontainer\n' > "${test_tmp}/env/chien-dev.yaml"
  touch "${test_tmp}/env/docker-compose.yml"

  do_clean demo || fail "clean failed for a stopped DevContainer"
  [[ "${prompt_called}" == "true" ]] || fail "confirmation was not requested"
  [[ "${compose_called}" == "true" ]] || fail "Compose cleanup was not run"
  assert_dir_missing "${test_tmp}/env"
}

test_unavailable_docker_status_is_refused() {
  setup_mocks || return
  printf 'backend: devcontainer\n' > "${test_tmp}/env/chien-dev.yaml"
  touch "${test_tmp}/env/docker-compose.yml"
  compose_project_is_running() { return 2; }

  if do_clean demo; then
    fail "clean unexpectedly succeeded without a reliable Docker status"
    return
  fi

  assert_dir_exists "${test_tmp}/env" || return
  [[ "${prompt_called}" == "false" ]] || fail "confirmation should not run after a status error"
}

test_devcontainer_started_during_prompt_is_refused() {
  setup_mocks || return
  printf 'backend: devcontainer\n' > "${test_tmp}/env/chien-dev.yaml"
  touch "${test_tmp}/env/docker-compose.yml"
  status_checks=0
  compose_project_is_running() {
    status_checks=$((status_checks + 1))
    [[ "${status_checks}" -ge 2 ]]
  }

  if do_clean demo; then
    fail "clean unexpectedly succeeded after the DevContainer started during confirmation"
    return
  fi

  assert_dir_exists "${test_tmp}/env" || return
  [[ "${prompt_called}" == "true" ]] || fail "confirmation was not requested"
  [[ "${compose_called}" == "false" ]] || fail "Compose cleanup should not run after the second status check"
}

test_running_vm_is_refused() {
  setup_mocks || return
  printf 'backend: vm\n' > "${test_tmp}/env/chien-dev.yaml"
  vm_exists() { return 0; }
  vm_get_status() { echo "Running"; }

  if do_clean demo; then
    fail "clean unexpectedly succeeded for a running VM"
    return
  fi

  assert_dir_exists "${test_tmp}/env" || return
  [[ "${prompt_called}" == "false" ]] || fail "confirmation should not run before the VM status guard"
  [[ "${vm_deleted}" == "false" ]] || fail "VM deletion should not run"
}

test_stopped_vm_is_cleaned() {
  setup_mocks || return
  printf 'backend: vm\n' > "${test_tmp}/env/chien-dev.yaml"
  vm_exists() { return 0; }

  do_clean demo || fail "clean failed for a stopped VM"
  [[ "${prompt_called}" == "true" ]] || fail "confirmation was not requested"
  [[ "${vm_deleted}" == "true" ]] || fail "VM deletion was not run"
  assert_dir_missing "${test_tmp}/env"
}

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SOURCE_DIR}/scripts/commands/clean.sh"

run_test "running DevContainer is refused" test_running_devcontainer_is_refused
run_test "stopped DevContainer is cleaned" test_stopped_devcontainer_is_cleaned
run_test "unavailable Docker status is refused" test_unavailable_docker_status_is_refused
run_test "DevContainer started during confirmation is refused" test_devcontainer_started_during_prompt_is_refused
run_test "running VM is refused" test_running_vm_is_refused
run_test "stopped VM is cleaned" test_stopped_vm_is_cleaned

echo "${TESTS_RUN} tests, ${TESTS_FAILED} failures"
[[ "${TESTS_FAILED}" -eq 0 ]]
