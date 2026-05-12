#!/usr/bin/env bash

do_status() {
  local env_name
  local env_dir
  local compose_file
  local found_any="false"
  ensure_dependencies
  env_name="${env_name_arg}"

  if [[ -n "${env_name}" ]]; then
    validate_env_name "${env_name}"
    compose_file="$(compose_file_for "${env_name}")"
    if [[ -f "${compose_file}" ]]; then
      print_env_status_table "${env_name}" "${compose_file}"
    else
      log_warn "Environment '${env_name}' not found. Run: make chien-dev create ${env_name}"
    fi
    return
  fi

  if [[ ! -d "${ENVS_DIR}" ]]; then
    log_info "No environments found. Run: make chien-dev create <name>"
    return
  fi

  for env_dir in "${ENVS_DIR}"/*; do
    if [[ ! -d "${env_dir}" ]]; then
      continue
    fi
    env_name="$(basename "${env_dir}")"
    compose_file="$(compose_file_for "${env_name}")"
    if [[ -f "${compose_file}" ]]; then
      found_any="true"
      print_env_status_table "${env_name}" "${compose_file}"
    fi
  done

  if [[ "${found_any}" == "false" ]]; then
    log_info "No environments found. Run: make chien-dev create <name>"
  fi
}
