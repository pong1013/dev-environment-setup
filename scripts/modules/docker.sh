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
