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
- [ ] Add non-interactive mode (for example: `make chien-dev start OS=ubuntu:22.04 SERVICES=postgres,redis ENV_NAME=my-dev-env`)
- [x] Add customizable environment name (used for dev container/service naming in startup)
- [ ] Improve `doctor` (port conflicts, daemon status, permissions)
- [ ] Add tests and CI (shellcheck + smoke tests)
- [ ] Phase 2: add VM backend (e.g. Multipass/Vagrant) — target use case: provision fake-GPU VMs and register them as Kubernetes nodes
