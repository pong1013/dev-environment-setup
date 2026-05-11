#!/usr/bin/env bash

do_help() {
  cat <<'EOF'
chien-dev | Dev Environment Setup

Usage:
  make chien-dev <command> [name] [PROJECT=/abs/path/to/repo]

Commands:
  doctor
    Check docker / docker compose / make availability.

  create <name>
    Interactive create a named environment and generate files under:
      generated/envs/<name>/

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
  make chien-dev start go-dev PROJECT=/abs/path/to/repo
  make chien-dev status
  make chien-dev shell go-dev
  make chien-dev stop go-dev
  make chien-dev clean go-dev
EOF
}
