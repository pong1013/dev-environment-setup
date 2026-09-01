#!/usr/bin/env bash

ensure_dependencies() {
  if ! command -v docker >/dev/null 2>&1; then
    log_error "docker not found. Please install Docker Desktop first."
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    log_error "docker compose is unavailable. Please update Docker."
    exit 1
  fi
}

compose_run() {
  local env_name="$1"
  local compose_file="$2"
  shift 2
  docker compose -p "${env_name}" -f "${compose_file}" "$@"
}

# Returns:
#   0 when the Compose project has one or more running containers
#   1 when the Compose project has no running containers
#   2 when Docker state cannot be inspected safely
compose_project_is_running() {
  local env_name="$1"
  local container_ids

  if ! container_ids="$(docker ps \
    --filter "label=com.docker.compose.project=${env_name}" \
    --quiet 2>/dev/null)"; then
    return 2
  fi

  [[ -n "${container_ids}" ]]
}
