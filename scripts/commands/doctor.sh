#!/usr/bin/env bash

do_doctor() {
  log_info "Running environment checks..."
  
  # 1. Tools presence
  local tools=("docker" "make" "git" "lsof")
  for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
      log_success "Tool '$tool' is installed."
    else
      log_error "Tool '$tool' is MISSING."
    fi
  done

  echo ""
  # 2. Docker Daemon Health
  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      log_success "Docker daemon is running."
    else
      log_error "Docker daemon is NOT running. Please start Docker Desktop."
    fi
  fi

  echo ""
  # 3. Port Scan
  log_info "Checking for common port conflicts..."
  local ports=(
    "80:HTTP"
    "443:HTTPS"
    "3306:MySQL"
    "5432:PostgreSQL"
    "6379:Redis"
    "27017:MongoDB"
    "5672:RabbitMQ"
    "9092:Kafka"
  )

  for p in "${ports[@]}"; do
    local port="${p%%:*}"
    local name="${p#*:}"
    if is_port_available "$port"; then
      echo "  [OK] Port $port ($name) is available."
    else
      local owner=$(get_port_owner "$port")
      log_warn "Port $port ($name) is BUSY. Occupied by: $owner"
    fi
  done

  echo ""
  log_info "Doctor check complete."
}
