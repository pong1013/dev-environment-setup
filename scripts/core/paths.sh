#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GENERATED_DIR="${ROOT_DIR}/generated"
ENVS_DIR="${GENERATED_DIR}/envs"

env_dir_for() {
  local env_name="$1"
  echo "${ENVS_DIR}/${env_name}"
}

config_file_for() {
  local env_name="$1"
  echo "$(env_dir_for "${env_name}")/chien-dev.yaml"
}

devcontainer_dir_for() {
  local env_name="$1"
  echo "$(env_dir_for "${env_name}")/.devcontainer"
}

compose_file_for() {
  local env_name="$1"
  echo "$(env_dir_for "${env_name}")/docker-compose.yml"
}
