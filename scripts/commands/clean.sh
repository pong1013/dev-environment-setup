#!/usr/bin/env bash

_ensure_clean_environment_stopped() {
  local env_name="$1"
  local backend="$2"
  local vm_is_present="$3"

  if [[ "${backend}" == "vm" && "${vm_is_present}" == "true" ]]; then
    local vm_status
    if ! vm_status="$(vm_get_status "${env_name}")" || [[ -z "${vm_status}" || "${vm_status}" == "null" ]]; then
      log_error "Unable to determine VM '${env_name}' status. Cleanup was not performed."
      return 1
    fi

    if [[ "${vm_status}" != "Stopped" ]]; then
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
  elif [[ -n "${backend}" ]]; then
    log_error "Unknown backend '${backend}' for environment '${env_name}'. Cleanup was not performed."
    return 1
  fi
}

do_clean() {
  local env_name
  local env_dir
  local config_file
  local compose_file
  local backend=""
  local vm_is_present="false"
  env_name="${1:-${env_name_arg:-}}"
  validate_env_name "${env_name}"

  env_dir="$(env_dir_for "${env_name}")"
  config_file="$(config_file_for "${env_name}")"
  compose_file="$(compose_file_for "${env_name}")"

  # Even if env_dir is missing, we check if a VM exists with that name
  if command -v multipass >/dev/null 2>&1; then
    if vm_exists "${env_name}"; then
      vm_is_present="true"
    fi
  fi

  if [[ ! -d "${env_dir}" && "${vm_is_present}" == "false" ]]; then
    log_warn "Environment '${env_name}' not found (no directory, no VM)."
    return
  fi

  # Prefer the recorded backend. For incomplete environments, infer it from
  # the generated files or an existing Multipass instance.
  if [[ -f "${config_file}" ]]; then
    backend=$(grep "backend:" "${config_file}" | awk '{print $2}')
  elif [[ -f "${env_dir}/cloud-init.yaml" || "${vm_is_present}" == "true" ]]; then
    backend="vm"
  elif [[ -f "${compose_file}" ]]; then
    backend="devcontainer"
  fi

  # Refuse destructive cleanup until the environment is fully stopped.
  if ! _ensure_clean_environment_stopped "${env_name}" "${backend}" "${vm_is_present}"; then
    return 1
  fi

  if ! prompt_yes_no "This will remove environment '${env_name}' assets and generated files. Continue?" "n"; then
    log_info "Cleanup cancelled."
    return
  fi

  # Check again after an interactive prompt in case the environment was
  # started while clean was waiting for confirmation.
  if ! _ensure_clean_environment_stopped "${env_name}" "${backend}" "${vm_is_present}"; then
    return 1
  fi

  if [[ "${backend}" == "vm" ]]; then
    if [[ "${vm_is_present}" == "true" ]]; then
      vm_delete "${env_name}"
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
