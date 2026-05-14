# chien-dev (dev-environment-setup)

<p align="center">
  <img src="https://img.shields.io/badge/Backend-Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/Backend-Multipass-0052CC?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Multipass">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
</p>

[English](./README.md) | [繁體中文](./README.zh-TW.md)

**chien-dev** is a standardized development environment scaffolder. It supports both **DevContainer** (Docker) and **Virtual Machine** (Multipass) backends to help you provision and manage isolated development setups with ease.

---

## Features

- **Dual Backend Support**: Seamlessly toggle between **Docker (DevContainer)** and **Virtual Machine (Multipass)**.
- **Interactive Setup**: Customize OS, languages, and services through a friendly CLI.
- **Smart Resource Detection**: Automatically suggests VM configurations based on host CPU/RAM/Disk.
- **SSH Security**: Automated SSH key management for VMs.
- **Doctor Check**: Built-in health checks for ports and dependencies.

---

## Demo

![Demo Screen Recording](./assets/dev_env_demo.gif)

---

## Usage

### Before Start

- Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (for Container mode)
- Install [Multipass](https://multipass.run/) (optional, for VM mode)

### Recommended First-time Flow

```bash
make chien-dev doctor
make chien-dev create <NAME>
make chien-dev start <NAME> PROJECT=/abs/path/to/repo
make chien-dev status
```

### Detailed Command Behavior

- `make chien-dev help`: Show command usage and examples.
- `make chien-dev create <name>`: Create a named environment (interactive or via env vars).
- `make chien-dev start <name> PROJECT=/path`: Start environment and mount project to `/workspace`.
- `make chien-dev status [name]`: Show all statuses or a specific environment's info.
- `make chien-dev shell <name>`: Enter workspace container bash (Container mode) or show SSH instructions (VM mode).
- `make chien-dev stop <name>`: Stop the environment.
- `make chien-dev clean <name>`: Safely remove the environment and its generated files.

### Non-interactive Mode (CI/CD Ready)

Pass any variable below to skip prompts:

```bash
# Create a VM environment
ENV=vm VM_CPUS=4 VM_MEM=4G make chien-dev create my-node

# Create a Container with specific languages
make chien-dev create my-dev LANGS=go,node DB=postgres
```

| Key | Values | Default |
|-----|--------|---------|
| `ENV` | `devcontainer`, `vm` | `devcontainer` |
| `OS` | `22.04`, `24.04` | `22.04` |
| `LANGS` | `go`, `node`, `python`, `java`, `php` | none |
| `FRONTEND` | `react`, `vue` | `none` |
| `DB` | `postgres`, `mysql`, `mongodb` | none |
| `BROKER` | `redis`, `rabbitmq`, `kafka` | none |

---

## Testing Your Environment

After `make chien-dev start <NAME>`, you can verify the setup:

```bash
# For Container Mode:
make chien-dev shell <NAME>
go version     # (or node --version, etc.)

# For VM Mode:
# Run the SSH command shown in 'make chien-dev status'
ssh ubuntu@<VM_IP>
```

---

## Structure & Extension

- `scripts/commands/`: CLI command handlers.
- `scripts/generators/`: Configuration renderers (`container_render.sh`, `vm_render.sh`).
- `scripts/modules/`: Shared logic for `docker.sh`, `vm.sh`, and `network.sh`.

---

## License

Distributed under the MIT License.
