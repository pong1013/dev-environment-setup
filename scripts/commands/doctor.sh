#!/usr/bin/env bash

do_doctor() {
  log_info "Running environment checks..."
  if command -v docker >/dev/null 2>&1; then
    echo "  - docker: OK"
  else
    log_warn "docker: MISSING"
  fi

  if docker compose version >/dev/null 2>&1; then
    echo "  - docker compose: OK"
  else
    log_warn "docker compose: MISSING"
  fi

  if command -v make >/dev/null 2>&1; then
    echo "  - make: OK"
  else
    log_warn "make: MISSING"
  fi
}
