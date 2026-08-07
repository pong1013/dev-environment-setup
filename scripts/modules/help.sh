#!/usr/bin/env bash

do_help() {
  cat <<'EOF'
chien-dev | Dev Environment Setup

Usage:
  chien-dev <command> [name] [options]

Commands:
  doctor
    Check docker / docker compose / make availability.

  create <name> [options]
    Interactive create a named environment and generate files under:
      generated/envs/<name>/
    Or non-interactive (pass any option below to skip prompts):
      chien-dev create <name> --langs go,node --db postgres --broker redis

    Supported options:
      --env, -e devcontainer|vm     Backend environment type (default: devcontainer)
      --os, -o 22.04|24.04         Ubuntu version (default: 22.04)
      --langs, -l go,node,...      Languages: go node python java php
      --frontend, -f react|vue|none Frontend framework
      --db, -d postgres,...        Databases: postgres mysql mongodb
      --broker, -b redis,...       Brokers: redis rabbitmq kafka
      --cpus, -c 4                 VM CPU count
      --memory, -m 4G              VM memory size
      --disk, -s 20G               VM disk size
      GO_VER, NODE_VER, PYTHON_VER, JAVA_VER, PHP_VER
      PG_VER, MYSQL_VER, MONGODB_VER, REDIS_VER, RABBITMQ_VER, KAFKA_VER

  start <name> [--project, -p /abs/path/to/repo]
    Start the environment and mount PROJECT, or the current directory, into /workspace.

  status [name]
    Show environment status table(s).

  shell <name>
    Enter the workspace container bash, or show SSH login instructions for VM environments.

  stop <name>
    Stop the given environment (name required).

  clean <name>
    Remove the given environment (name required).
    Safety: environment must be stopped first.

Examples:
  chien-dev doctor
  chien-dev create go-dev
  chien-dev create go-dev --langs go --db postgres
  chien-dev create ci-env --langs go,node -f react --db postgres -b redis GO_VER=1.22.0
  chien-dev start go-dev --project /abs/path/to/repo
  chien-dev status
  chien-dev shell go-dev
  chien-dev stop go-dev
  chien-dev clean go-dev
EOF
}
