#!/usr/bin/env bash

do_start() {
  local env_name
  local env_dir
  local compose_file
  local project_path="${PROJECT:-}"
  ensure_dependencies
  env_name="${env_name_arg}"
  validate_env_name "${env_name}"
  validate_project_path "${project_path}"
  env_dir="$(env_dir_for "${env_name}")"
  compose_file="$(compose_file_for "${env_name}")"

  if [[ ! -d "${env_dir}" || ! -f "${compose_file}" ]]; then
    echo "Environment '${env_name}' not found. Creating it now..."
    do_create
  fi
  compose_file="$(compose_file_for "${env_name}")"
  echo "Starting development environment: ${env_name}"
  if [[ -n "${project_path}" ]]; then
    echo "Mounting project path: ${project_path}"
    PROJECT_PATH="${project_path}" compose_run "${env_name}" "${compose_file}" up -d
  else
    compose_run "${env_name}" "${compose_file}" up -d
  fi
  echo "Done. You can now open this project in a dev container."
}
