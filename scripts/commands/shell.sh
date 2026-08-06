#!/usr/bin/env bash

do_shell() {
  local env_name
  local config_file
  local backend
  local compose_file
  env_name="${1:-${env_name_arg:-}}"
  validate_env_name "${env_name}"

  config_file="$(config_file_for "${env_name}")"
  if [[ ! -f "${config_file}" ]]; then
    log_error "Environment '${env_name}' not found. Run: chien-dev create ${env_name}"
    exit 1
  fi

  backend=$(grep "backend:" "${config_file}" | awk '{print $2}')

  if [[ "${backend}" == "vm" ]]; then
    ensure_multipass
    if ! vm_exists "${env_name}"; then
      log_error "VM '${env_name}' does not exist in Multipass. Run: chien-dev clean ${env_name}"
      exit 1
    fi
    ssh "ubuntu@$(vm_get_ip "${env_name}")"
  else
    ensure_dependencies
    compose_file="$(compose_file_for "${env_name}")"
    if [[ ! -f "${compose_file}" ]]; then
      log_error "Compose file missing for environment: ${env_name}"
      exit 1
    fi
    compose_run "${env_name}" "${compose_file}" exec workspace bash
  fi
}
