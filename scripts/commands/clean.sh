#!/usr/bin/env bash

do_clean() {
  local env_name
  local env_dir
  local compose_file
  local running_services
  ensure_dependencies
  env_name="${env_name_arg}"

  if [[ -z "${env_name}" ]]; then
    log_error "clean requires an environment name (prevents wiping every stack and generated files by mistake)."
    log_info "Usage: make chien-dev clean <name>"
    log_info "To remove another environment, run clean again with that name."
    exit 1
  fi

  validate_env_name "${env_name}"
  env_dir="$(env_dir_for "${env_name}")"
  compose_file="$(compose_file_for "${env_name}")"
  if [[ ! -d "${env_dir}" ]]; then
    log_error "Environment '${env_name}' not found."
    exit 1
  fi

  running_services="$(compose_run "${env_name}" "${compose_file}" ps --status running --services 2>/dev/null || true)"
  if [[ -n "${running_services}" ]]; then
    log_error "environment '${env_name}' is still running."
    log_info "Please stop it first: make chien-dev stop ${env_name}"
    log_info "Running services:"
    while IFS= read -r service; do
      [[ -n "${service}" ]] && echo "  - ${service}"
    done <<< "${running_services}"
    exit 1
  fi

  if ! prompt_yes_no "This will remove environment '${env_name}' containers, volumes and generated files. Continue?" "n"; then
    log_info "Cancelled."
    exit 0
  fi
  compose_run "${env_name}" "${compose_file}" down -v --remove-orphans || true
  rm -rf "${env_dir}"
  log_success "Environment '${env_name}' cleanup completed."
}
