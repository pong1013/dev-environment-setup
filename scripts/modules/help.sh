#!/usr/bin/env bash

do_help() {
  cat <<'EOF'
chien-dev | Dev Environment Setup

Usage:
  make chien-dev <command> [name] [KEY=value ...]

Commands:
  doctor
    Check docker / docker compose / make availability.

  create <name> [KEY=value ...]
    Interactive create a named environment and generate files under:
      generated/envs/<name>/
    Or non-interactive (pass any variable below to skip prompts):
      LANGS=go,node DB=postgres BROKER=redis make chien-dev create <name>

    Supported keys:
      OS=22.04|24.04        Ubuntu version (default: 22.04)
      LANGS=go,node,...     Languages: go node python java php  (note: LANGS not LANG)
      FRONTEND=react|vue    Frontend framework (default: none)
      DB=postgres,...       Databases: postgres mysql mongodb
      BROKER=redis,...      Brokers: redis rabbitmq kafka
      GO_VER, NODE_VER, PYTHON_VER, JAVA_VER, PHP_VER
      PG_VER, MYSQL_VER, MONGODB_VER, REDIS_VER, RABBITMQ_VER, KAFKA_VER

  start <name> [PROJECT=/abs/path/to/repo]
    Start the environment. If PROJECT is provided, mount it into /workspace.

  status [name]
    Show environment status table(s).

  shell <name>
    Enter the workspace container bash for the given environment.

  stop <name>
    Stop the given environment (name required).

  clean <name>
    Remove the given environment (name required).
    Safety: environment must be stopped first.

Examples:
  make chien-dev doctor
  make chien-dev create go-dev
  make chien-dev create go-dev LANGS=go DB=postgres
  make chien-dev create ci-env LANGS=go,node FRONTEND=react DB=postgres BROKER=redis GO_VER=1.22.0
  make chien-dev start go-dev PROJECT=/abs/path/to/repo
  make chien-dev status
  make chien-dev shell go-dev
  make chien-dev stop go-dev
  make chien-dev clean go-dev
EOF
}
