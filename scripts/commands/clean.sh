#!/usr/bin/env bash

do_clean() {
  local env_name
  local env_dir
  local config_file
  local backend=""
  env_name="${1:-${env_name_arg:-}}"
  validate_env_name "${env_name}"

  env_dir="$(env_dir_for "${env_name}")"
  config_file="$(config_file_for "${env_name}")"

  # Even if env_dir is missing, we check if a VM exists with that name
  local vm_is_present="false"
  if command -v multipass >/dev/null 2>&1; then
    if vm_exists "${env_name}"; then
      vm_is_present="true"
    fi
  fi

  if [[ ! -d "${env_dir}" && "${vm_is_present}" == "false" ]]; then
    log_warn "Environment '${env_name}' not found (no directory, no VM)."
    return
  fi

  if ! prompt_yes_no "This will remove environment '${env_name}' assets and generated files. Continue?" "n"; then
    log_info "Cleanup cancelled."
    return
  fi

  # Try to determine backend from config if it exists
  if [[ -f "${config_file}" ]]; then
    backend=$(grep "backend:" "${config_file}" | awk '{print $2}')
  fi

  # Cleanup VM if it exists or if backend is vm
  if [[ "${vm_is_present}" == "true" ]]; then
    vm_delete "${env_name}"
  elif [[ "${backend}" == "vm" ]]; then
    log_warn "VM '${env_name}' does not exist in Multipass; removing generated files only."
  fi

  # Cleanup Docker if backend is devcontainer
  if [[ "${backend}" == "devcontainer" ]]; then
    ensure_dependencies
    local compose_file="$(compose_file_for "${env_name}")"
    if [[ -f "${compose_file}" ]]; then
      docker compose -f "${compose_file}" down -v --remove-orphans || true
    fi
  fi

  # Final directory cleanup
  if [[ -d "${env_dir}" ]]; then
    rm -rf "${env_dir}"
  fi
  
  log_success "Environment '${env_name}' cleanup completed."
}
