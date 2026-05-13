#!/usr/bin/env bash

log_info() {
  printf "info: %s\n" "$*"
}

log_warn() {
  printf "\033[33m! warn:\033[0m %s\n" "$*" >&2
}

log_error() {
  printf "\033[31m✘ error:\033[0m %s\n" "$*" >&2
}

log_success() {
  printf "\033[32m✔ success:\033[0m %s\n" "$*"
}
