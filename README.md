# dev-environment-setup

[English](./README.md) | [繁體中文](./README.zh-TW.md)

A standardized development environment scaffold. Use named environments (for example `go-dev`, `node-dev`) to generate and manage DevContainer-based setups.

## Before Start

Complete the following prerequisites before your first run:

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (with Docker Compose v2)
2. Start Docker Desktop and make sure Docker daemon is running
3. Verify required commands
   ```bash
   docker --version
   docker compose version
   make --version
   ```

If you are using Linux, make sure `docker`, `docker compose`, and `make` are installed, and your current user can run Docker commands without `sudo`.

## MVP Features

- Interactive environment creation (Ubuntu version, language stacks, services, and environment name)
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

Quick start (compatible with previous command style):

```bash
make chien-dev create <NAME>
make chien-dev start <NAME> PROJECT=/abs/path/to/repo
```

Non-interactive mode (pass any variable below to skip all prompts):

```bash
# Install only Go (nothing else)
make chien-dev create my-dev LANGS=go

# Specify languages and database
make chien-dev create my-dev LANGS=python,java DB=postgres

# Full specification with version overrides
make chien-dev create ci-env LANGS=go,node FRONTEND=react DB=postgres BROKER=redis GO_VER=1.22.0 PG_VER=15
```

Supported keys for non-interactive mode:

| Key | Values | Default |
|-----|--------|---------|
| `OS` | `22.04`, `24.04` | `22.04` |
| `LANGS` | `go`, `node`, `python`, `java`, `php` (comma-separated) | none |
| `FRONTEND` | `none`, `react`, `vue` | `none` |
| `DB` | `postgres`, `mysql`, `mongodb` (comma-separated) | none |
| `BROKER` | `redis`, `rabbitmq`, `kafka` (comma-separated) | none |
| `GO_VER`, `NODE_VER`, `PYTHON_VER`, `JAVA_VER`, `PHP_VER` | version strings | LTS defaults |
| `PG_VER`, `MYSQL_VER`, `MONGODB_VER`, `REDIS_VER`, `RABBITMQ_VER`, `KAFKA_VER` | version strings | LTS defaults |

> **Note**: Use `LANGS` (not `LANG`) to avoid conflict with the system `LANG` variable.

Behavior:

- `make chien-dev help`: show command usage and examples
- `make chien-dev create <name>`: create a named environment (name is required)
- `make chien-dev start <name> PROJECT=/abs/path/to/repo`: start that environment and mount target project to `/workspace`
- `make chien-dev status`: show all environment statuses
- `make chien-dev status <name>`: show one environment status
- `make chien-dev shell <name>`: open bash in the workspace container

Available subcommands:

- `start <name>`: create (if needed) and start a named environment (`PROJECT` can mount a target project directory to `/workspace`)
- `create <name>`: interactive setup and file generation for a named environment
- `stop <name>`: stop one named environment (name is required)
- `status [name]`: show all statuses or one named environment
- `shell <name>`: enter workspace container bash for one named environment
- `doctor`: check docker / compose / make
- `clean <name>`: remove one named environment only (name is required, and the environment must be stopped first)

## Enter Environment and Test

After `make chien-dev start <NAME> PROJECT=/abs/path/to/repo`, you can enter the workspace container:

```bash
make chien-dev shell <NAME>
```

Run a quick smoke test inside the container:

```bash
go version
node --version
git --version
```

You can also open this repository with a Dev Container in Cursor/VS Code:

1. Open command palette(cmd + Shift + P)
2. Select `Dev Containers: Reopen in Container`(Need Dev Containers Extension)
3. Run the same smoke test commands in the integrated terminal

## Codebase Structure

`scripts/` is now split by responsibility to keep the CLI maintainable:

- `scripts/chien-dev`: thin entrypoint (module loading + command dispatch)
- `scripts/commands/`: command handlers (`create/start/stop/status/shell/doctor/clean`)
- `scripts/core/`: shared paths and validation helpers
- `scripts/generators/`: generated file renderers (`chien-dev.yaml`, `.devcontainer`, compose)
- `scripts/modules/`: shared runtime modules (prompt, docker helpers, status output, help text)


## TODO

- [x] Define naming convention (repo/CLI/config)
- [x] Implement MVP command skeleton (`start/create/stop/status/doctor/clean`)
- [x] Add interactive menu to generate `chien-dev.yaml`
- [x] Generate `.devcontainer` and `docker-compose.yml`
- [x] Add README basic usage and pre-start checklist
- [x] Add non-interactive mode (`LANGS=go,node DB=postgres make chien-dev create <name>`)
- [x] Add customizable environment name (used for dev container/service naming in startup)
- [ ] Improve `doctor` (port conflicts, daemon status, permissions)
- [ ] Add tests and CI (shellcheck + smoke tests)
- [ ] Phase 2: add VM backend (e.g. Multipass/Vagrant) — target use case: provision fake-GPU VMs and register them as Kubernetes nodes
