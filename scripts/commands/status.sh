#!/usr/bin/env bash

do_status() {
  local env_name
  local env_dir
  local config_file
  local found_any="false"
  
  env_name="${1:-${env_name_arg:-}}"

  if [[ -n "${env_name}" ]]; then
    validate_env_name "${env_name}"
    config_file="$(config_file_for "${env_name}")"
    if [[ -f "${config_file}" ]]; then
      _print_single_status "${env_name}" "${config_file}"
    else
      log_warn "Environment '${env_name}' not found. Run: chien-dev create ${env_name}"
    fi
    return
  fi

  if [[ ! -d "${ENVS_DIR}" ]]; then
    log_info "No environments found. Run: chien-dev create <name>"
    return
  fi

  for env_dir in "${ENVS_DIR}"/*; do
    if [[ ! -d "${env_dir}" ]]; then
      continue
    fi
    env_name="$(basename "${env_dir}")"
    config_file="$(config_file_for "${env_name}")"
    if [[ -f "${config_file}" ]]; then
      found_any="true"
      _print_single_status "${env_name}" "${config_file}"
    fi
  done

  if [[ "${found_any}" == "false" ]]; then
    log_info "No environments found. Run: chien-dev create <name>"
  fi
}

_print_single_status() {
  local env_name="$1"
  local config_file="$2"
  local backend=$(grep "backend:" "${config_file}" | awk '{print $2}')
  
  if [[ "${backend}" == "vm" ]]; then
    echo "=== ${env_name} (VM) ==="
    if ! vm_exists "${env_name}"; then
      echo "  State: Missing"
      echo "  IP:    N/A"
      echo "  Hint:  chien-dev clean ${env_name}"
      echo ""
      return
    fi
    local state=$(vm_get_status "${env_name}")
    local ip=$(vm_get_ip "${env_name}")
    echo "  State: ${state:-Unknown}"
    echo "  IP:    ${ip:-N/A}"
    echo "  Login: ssh ubuntu@${ip}"
    echo ""
  else
    local compose_file="$(compose_file_for "${env_name}")"
    if [[ -f "${compose_file}" ]]; then
      print_env_status_table "${env_name}" "${compose_file}"
    else
      echo "=== ${env_name} (Container) ==="
      echo "  Error: docker-compose.yml missing."
      echo ""
    fi
  fi
}
