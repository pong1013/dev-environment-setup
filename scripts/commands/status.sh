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
    local vm_entry
    if ! vm_entry="$(vm_get_inventory_entry "${env_name}")"; then
      echo "  State: Unknown"
      echo "  IP:    N/A"
      echo "  Hint:  Unable to query Multipass; check its service and permissions."
      echo ""
      return
    fi
    if [[ "$(printf '%s\n' "${vm_entry}" | jq -r '.present')" == "false" ]]; then
      echo "  State: Missing"
      echo "  IP:    N/A"
      echo "  Hint:  chien-dev clean ${env_name} (remove stale generated files)"
      echo ""
      return
    fi
    local state
    local ip
    state="$(printf '%s\n' "${vm_entry}" | jq -r '.state')"
    ip="$(printf '%s\n' "${vm_entry}" | jq -r '.ipv4[0] // empty')"
    echo "  State: ${state:-Unknown}"
    echo "  IP:    ${ip:-N/A}"
    if [[ -n "${ip}" ]]; then
      echo "  Login: ssh ubuntu@${ip}"
    fi
    if [[ "${state}" == "Deleted" ]]; then
      echo "  Hint:  chien-dev clean ${env_name}"
    fi
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
