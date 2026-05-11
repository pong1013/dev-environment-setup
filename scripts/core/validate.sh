#!/usr/bin/env bash

validate_env_name() {
  local env_name="$1"
  if [[ -z "${env_name}" ]]; then
    echo "Error: environment name is required."
    exit 1
  fi
  if [[ ! "${env_name}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
    echo "Error: invalid environment name '${env_name}'. Use letters, numbers, '-' or '_'."
    exit 1
  fi
}

validate_project_path() {
  local project_path="$1"
  if [[ -z "${project_path}" ]]; then
    return 0
  fi
  if [[ "${project_path}" != /* ]]; then
    echo "Error: PROJECT must be an absolute path, got: ${project_path}"
    exit 1
  fi
  if [[ ! -d "${project_path}" ]]; then
    echo "Error: PROJECT path does not exist or is not a directory: ${project_path}"
    exit 1
  fi
}
