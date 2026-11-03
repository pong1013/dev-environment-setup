#!/usr/bin/env bash

_ensure_clean_environment_stopped() {
  local env_name="$1"
  local backend="$2"
  local vm_entry="${3:-}"

  if [[ "${backend}" == "vm" ]]; then
    local vm_status
    vm_status="$(printf '%s\n' "${vm_entry}" | jq -r '.state')"
    if [[ "$(printf '%s\n' "${vm_entry}" | jq -r '.present')" == "true" && "${vm_status}" != "Stopped" && "${vm_status}" != "Deleted" ]]; then
      log_error "VM '${env_name}' is ${vm_status}. Stop it before cleaning: chien-dev stop ${env_name}"
      return 1
    fi
  elif [[ "${backend}" == "devcontainer" ]]; then
    ensure_dependencies

    local docker_status=0
    compose_project_is_running "${env_name}" || docker_status=$?
    case "${docker_status}" in
      0)
        log_error "DevContainer environment '${env_name}' is running. Stop it before cleaning: chien-dev stop ${env_name}"
        return 1
        ;;
      1)
        ;;
      *)
        log_error "Unable to determine DevContainer environment '${env_name}' status. Cleanup was not performed."
        return 1
        ;;
    esac
  else
    log_error "Unknown backend '${backend:-unrecorded}' for environment '${env_name}'. Cleanup was not performed."
    return 1
  fi
}

do_clean() {
  local env_name
  local env_dir
  local config_file
  local compose_file
  local backend=""
  local vm_before=""
  local vm_after=""
  env_name="${1:-${env_name_arg:-}}"
  validate_env_name "${env_name}"

  env_dir="$(env_dir_for "${env_name}")"
  config_file="$(config_file_for "${env_name}")"
  compose_file="$(compose_file_for "${env_name}")"

  # Prefer the recorded backend. For incomplete environments, infer it from
  # the generated files or an existing Multipass instance.
  if [[ -f "${config_file}" ]]; then
    backend=$(grep "backend:" "${config_file}" | awk '{print $2}')
  elif [[ -f "${env_dir}/cloud-init.yaml" ]]; then
    backend="vm"
  elif [[ -f "${compose_file}" ]]; then
    backend="devcontainer"
  fi

  if [[ -z "${backend}" ]] && command -v multipass >/dev/null 2>&1; then
    if ! vm_before="$(vm_get_inventory_entry "${env_name}")"; then
      log_error "Unable to determine VM '${env_name}' status. Cleanup was not performed."
      return 1
    fi
    if [[ "$(printf '%s\n' "${vm_before}" | jq -r '.present')" == "true" ]]; then
      backend="vm"
    fi
  fi

  if [[ ! -d "${env_dir}" && -z "${backend}" ]]; then
    log_warn "Environment '${env_name}' not found (no directory, no VM)."
    return
  fi

  if [[ "${backend}" == "vm" && -z "${vm_before}" ]]; then
    if ! vm_before="$(vm_get_inventory_entry "${env_name}")"; then
      log_error "Unable to determine VM '${env_name}' status. Cleanup was not performed."
      return 1
    fi
  fi

  # Inspect before asking, then refresh the same exact instance after consent.
  if ! _ensure_clean_environment_stopped "${env_name}" "${backend}" "${vm_before}"; then
    return 1
  fi
  if [[ "${backend}" == "vm" && "$(printf '%s\n' "${vm_before}" | jq -r '.present')" == "false" ]]; then
    log_warn "VM '${env_name}' is missing; cleanup will remove its generated files only."
  fi

  if ! prompt_yes_no "This will remove environment '${env_name}' assets and generated files. Continue?" "n"; then
    log_info "Cleanup cancelled."
    return
  fi

  if [[ "${backend}" == "vm" ]]; then
    if ! vm_after="$(vm_get_inventory_entry "${env_name}")"; then
      log_error "Unable to determine VM '${env_name}' status after confirmation. Cleanup was not performed."
      return 1
    fi
  fi
  if ! _ensure_clean_environment_stopped "${env_name}" "${backend}" "${vm_after}"; then
    return 1
  fi

  if [[ "${backend}" == "vm" ]]; then
    if [[ "$(printf '%s\n' "${vm_after}" | jq -r '.present')" == "true" ]]; then
      if [[ "$(printf '%s\n' "${vm_before}" | jq -r '.present')" == "false" ]]; then
        log_error "VM '${env_name}' appeared during confirmation. Cleanup was not performed; retry to inspect it."
        return 1
      fi
      if ! vm_delete "${env_name}"; then
        log_error "Failed to delete VM '${env_name}'; generated files were preserved."
        return 1
      fi
    else
      log_warn "VM '${env_name}' does not exist in Multipass; removing generated files only."
    fi
  elif [[ "${backend}" == "devcontainer" ]]; then
    if [[ -f "${compose_file}" ]]; then
      compose_run "${env_name}" "${compose_file}" down -v --remove-orphans
    fi
  fi

  # Final directory cleanup
  if [[ -d "${env_dir}" ]]; then
    rm -rf "${env_dir}"
  fi
  
  log_success "Environment '${env_name}' cleanup completed."
}
