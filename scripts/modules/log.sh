#!/usr/bin/env bash

log_info() {
  printf "info: %s\n" "$*"
}

log_warn() {
  printf "warn: %s\n" "$*" >&2
}

log_error() {
  printf "error: %s\n" "$*" >&2
}

log_success() {
  log_info "$*"
}
