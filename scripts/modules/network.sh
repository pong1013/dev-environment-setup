#!/usr/bin/env bash

# Check if a port is available on the host
# Returns 0 if free, 1 if busy
is_port_available() {
  local port=$1
  if lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# Find the first available port starting from a base port
find_available_port() {
  local port=$1
  while ! is_port_available "$port"; do
    port=$((port + 1))
  done
  echo "$port"
}

# Get the process name and PID using a port
get_port_owner() {
  local port=$1
  local pid
  pid=$(lsof -Pi :"$port" -sTCP:LISTEN -t | head -n 1)
  if [[ -n "$pid" ]]; then
    local proc
    proc=$(ps -p "$pid" -o comm=)
    echo "$proc (PID: $pid)"
  else
    echo "unknown"
  fi
}
