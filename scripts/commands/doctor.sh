#!/usr/bin/env bash

do_doctor() {
  echo "Running environment checks..."
  if command -v docker >/dev/null 2>&1; then
    echo "  - docker: OK"
  else
    echo "  - docker: MISSING"
  fi

  if docker compose version >/dev/null 2>&1; then
    echo "  - docker compose: OK"
  else
    echo "  - docker compose: MISSING"
  fi

  if command -v make >/dev/null 2>&1; then
    echo "  - make: OK"
  else
    echo "  - make: MISSING"
  fi
}
