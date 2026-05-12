#!/usr/bin/env bash

do_stop() {
  local env_name
  local compose_file
  ensure_dependencies
  env_name="${env_name_arg}"
  if [[ -z "${env_name}" ]]; then
    log_error "stop requires an environment name (prevents stopping every stack by mistake)."
    log_info "Usage: make chien-dev stop <name>"
    exit 1
  fi
  validate_env_name "${env_name}"
  compose_file="$(compose_file_for "${env_name}")"

  if [[ -f "${compose_file}" ]]; then
    compose_run "${env_name}" "${compose_file}" down
  else
    log_warn "Environment '${env_name}' not found. Nothing to stop."
  fi
}
