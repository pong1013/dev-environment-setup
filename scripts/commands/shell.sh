#!/usr/bin/env bash

do_shell() {
  local env_name
  local compose_file
  ensure_dependencies
  env_name="${env_name_arg}"
  validate_env_name "${env_name}"
  compose_file="$(compose_file_for "${env_name}")"

  if [[ ! -f "${compose_file}" ]]; then
    echo "Environment '${env_name}' not found. Run: make chien-dev create ${env_name}"
    exit 1
  fi

  compose_run "${env_name}" "${compose_file}" exec workspace bash
}
