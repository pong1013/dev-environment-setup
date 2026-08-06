#!/usr/bin/env bash

do_stop() {
  local env_name
  local config_file
  local backend
  env_name="${1:-${env_name_arg:-}}"
  validate_env_name "${env_name}"

  config_file="$(config_file_for "${env_name}")"
  if [[ ! -f "${config_file}" ]]; then
    log_warn "Environment '${env_name}' not found. Nothing to stop."
    return
  fi

  backend=$(grep "backend:" "${config_file}" | awk '{print $2}')

  if [[ "${backend}" == "vm" ]]; then
    ensure_multipass
    if ! vm_exists "${env_name}"; then
      log_warn "VM '${env_name}' does not exist in Multipass. Run: chien-dev clean ${env_name}"
      return
    fi
    vm_stop "${env_name}"
    log_success "VM environment '${env_name}' stopped."
  else
    ensure_dependencies
    local compose_file="$(compose_file_for "${env_name}")"
    if [[ -f "${compose_file}" ]]; then
      log_info "Stopping development environment: ${env_name}"
      docker compose -f "${compose_file}" down
      log_success "Environment '${env_name}' stopped."
    else
      log_warn "Compose file for '${env_name}' not found. Nothing to stop."
    fi
  fi
}
