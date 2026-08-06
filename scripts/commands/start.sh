#!/usr/bin/env bash

do_start() {
  local env_name
  local config_file
  local backend
  local project_path="${PROJECT_PATH:-${PROJECT:-}}"
  env_name="${1:-${env_name_arg:-}}"
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      PROJECT=*)
        project_path="${1#PROJECT=}"
        ;;
      PROJECT_PATH=*)
        project_path="${1#PROJECT_PATH=}"
        ;;
      *)
        log_error "Unknown argument for start: $1"
        log_info "Usage: chien-dev start <name> [PROJECT=/abs/path/to/repo]"
        exit 1
        ;;
    esac
    shift
  done
  
  if [[ -z "${env_name}" ]]; then
    log_error "Usage: chien-dev start <name> [PROJECT=/abs/path/to/repo]"
    exit 1
  fi

  validate_env_name "${env_name}"
  validate_project_path "${project_path}"
  config_file="$(config_file_for "${env_name}")"

  if [[ ! -f "${config_file}" ]]; then
    log_warn "Environment '${env_name}' not found. Creating it first..."
    do_create
    # Reload config after creation
    config_file="$(config_file_for "${env_name}")"
  fi

  backend=$(grep "backend:" "${config_file}" | awk '{print $2}')

  if [[ "${backend}" == "vm" ]]; then
    ensure_multipass
    log_info "Starting VM environment: ${env_name}"
    multipass start "${env_name}"
    local ip=$(vm_get_ip "${env_name}")
    log_success "VM '${env_name}' is running at ${ip}"
  else
    ensure_dependencies
    local compose_file="$(compose_file_for "${env_name}")"
    if [[ ! -f "${compose_file}" ]]; then
      log_error "Compose file missing for environment: ${env_name}"
      exit 1
    fi

    log_info "Starting development environment: ${env_name}"
    PROJECT_PATH="${project_path}" compose_run "${env_name}" "${compose_file}" up -d
  fi
}
