# dev-environment-setup

[English](./README.md) | [繁體中文](./README.zh-TW.md)

A standardized development environment scaffold. Supports both **DevContainer** (Docker-based) and **Virtual Machine** (Multipass-based) backends to generate and manage isolated development setups.

## Before Start

Complete the following prerequisites before your first run:

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (with Docker Compose v2)
2. Start Docker Desktop and make sure Docker daemon is running
3. **(Optional)** Install [Multipass](https://multipass.run/) if you plan to use VM-based environments
4. Verify required commands
   ```bash
   docker --version
   docker compose version
   make --version
   multipass version # optional
   ```

If you are using Linux, make sure `docker`, `docker compose`, and `make` are installed, and your current user can run Docker commands without `sudo`.

## MVP Features

- Interactive environment creation (Backend type, Ubuntu version, language stacks, services, and environment name)
- Supports dual backends: **DevContainer** (Docker) and **Virtual Machine** (Multipass)
- Generates per-environment files under `generated/envs/<name>/`
- Start, stop, status, doctor checks, and cleanup commands

## Usage

Recommended first-time flow:

```bash
make chien-dev doctor
make chien-dev create <NAME>
make chien-dev start <NAME> PROJECT=/abs/path/to/repo
make chien-dev status
```

### VM Backend Usage

To create a Virtual Machine environment instead of a DevContainer:

```bash
ENV=vm make chien-dev create my-vm
```

Once created, you can see the VM IP and login instructions using `make chien-dev status`.

### Non-interactive Mode

Pass any variable below to skip all prompts:

```bash
# Create a VM environment
ENV=vm make chien-dev create my-node

# Install only Go in a DevContainer
make chien-dev create my-dev LANGS=go

# Specify languages and database
make chien-dev create my-dev LANGS=python,java DB=postgres
```

Supported keys for non-interactive mode:

| Key | Values | Default |
|-----|--------|---------|
| `ENV` | `devcontainer`, `vm` | `devcontainer` |
| `OS` | `22.04`, `24.04` | `22.04` |
| `LANGS` | `go`, `node`, `python`, `java`, `php` (comma-separated) | none |
| `FRONTEND` | `none`, `react`, `vue` | `none` |
| `DB` | `postgres`, `mysql`, `mongodb` (comma-separated) | none |
| `BROKER` | `redis`, `rabbitmq`, `kafka` (comma-separated) | none |
| `GO_VER`, `NODE_VER`, `PYTHON_VER`, `JAVA_VER`, `PHP_VER` | version strings | LTS defaults |
| `PG_VER`, `MYSQL_VER`, `MONGODB_VER`, `REDIS_VER`, `RABBITMQ_VER`, `KAFKA_VER` | version strings | LTS defaults |

> **Note**: Use `LANGS` (not `LANG`) to avoid conflict with the system `LANG` variable.

## Codebase Structure

`scripts/` is organized by backend and responsibility:

- `scripts/commands/`: command handlers (`create/start/stop/status/shell/doctor/clean`)
- `scripts/generators/`: backend-specific renderers
  - `container_render.sh`: DevContainer & Docker Compose
  - `vm_render.sh`: Cloud-init for Multipass
- `scripts/modules/`: shared runtime modules
  - `docker.sh`: Docker/Compose helpers
  - `vm.sh`: Multipass helpers
  - `network.sh`: Port scanning and detection
- `scripts/core/`: shared paths and validation helpers

## TODO

- [x] Define naming convention (repo/CLI/config)
- [x] Implement MVP command skeleton (`start/create/stop/status/doctor/clean`)
- [x] Add interactive menu to generate `chien-dev.yaml`
- [x] Generate `.devcontainer` and `docker-compose.yml`
- [x] Add README basic usage and pre-start checklist
- [x] Add non-interactive mode (`LANGS=go,node DB=postgres make chien-dev create <name>`)
- [x] Add customizable environment name (used for dev container/service naming in startup)
- [x] Improve `doctor` (port conflicts, daemon status, permissions)
- [ ] Add tests and CI (shellcheck + smoke tests)
- [x] Phase 2: add VM backend (Multipass)
