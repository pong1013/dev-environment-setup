#!/usr/bin/env bash

render_config() {
  local target_config_file="$1"
  local env_name="$2"
  local os_version="$3"
  local include_go="$4"
  local include_node="$5"
  local include_pg="$6"
  local include_redis="$7"

  cat > "${target_config_file}" <<EOF
version: 1
name: ${env_name}
backend: devcontainer

os:
  distro: ubuntu
  version: "${os_version}"

languages:
  go: ${include_go}
  node: ${include_node}

features:
  system_tools: true
  git_ssh: true
  docker_compose: true
  make_lint: true
  project_init: true

services:
  postgres:
    enabled: ${include_pg}
    version: "16"
    port: 5432
  redis:
    enabled: ${include_redis}
    version: "7"
    port: 6379
EOF
}

render_devcontainer() {
  local target_devcontainer_dir="$1"
  local env_name="$2"
  local os_version="$3"
  local include_go="$4"
  local include_node="$5"
  mkdir -p "${target_devcontainer_dir}" "${GENERATED_DIR}"

  cat > "${target_devcontainer_dir}/Dockerfile" <<EOF
FROM ubuntu:${os_version}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \\
    ca-certificates curl wget jq unzip git openssh-client make build-essential \\
    gnupg lsb-release software-properties-common && \\
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
EOF

  if [[ "${include_go}" == "true" ]]; then
    cat >> "${target_devcontainer_dir}/Dockerfile" <<'EOF'

# Go
RUN curl -fsSL https://go.dev/dl/go1.23.0.linux-amd64.tar.gz -o /tmp/go.tar.gz && \
    rm -rf /usr/local/go && tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm -f /tmp/go.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"
EOF
  fi

  if [[ "${include_node}" == "true" ]]; then
    cat >> "${target_devcontainer_dir}/Dockerfile" <<'EOF'

# Node.js LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get update && apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*
EOF
  fi

  cat > "${target_devcontainer_dir}/devcontainer.json" <<EOF
{
  "name": "${env_name}",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "workspace",
  "workspaceFolder": "/workspace",
  "customizations": {
    "vscode": {
      "extensions": [
        "golang.go",
        "dbaeumer.vscode-eslint",
        "ms-azuretools.vscode-docker"
      ]
    }
  }
}
EOF
}

render_compose() {
  local target_compose_file="$1"
  local default_project_path="$2"
  local include_pg="$3"
  local include_redis="$4"

  cat > "${target_compose_file}" <<EOF
services:
  workspace:
    build:
      context: ./.devcontainer
      dockerfile: Dockerfile
    volumes:
      - \${PROJECT_PATH:-${default_project_path}}:/workspace
    command: sleep infinity
EOF

  if [[ "${include_pg}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: devdb
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
EOF
  fi

  if [[ "${include_redis}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'
  redis:
    image: redis:7
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
EOF
  fi

  if [[ "${include_pg}" == "true" || "${include_redis}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'

volumes:
EOF
  fi

  if [[ "${include_pg}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'
  postgres-data:
EOF
  fi

  if [[ "${include_redis}" == "true" ]]; then
    cat >> "${target_compose_file}" <<'EOF'
  redis-data:
EOF
  fi
}
