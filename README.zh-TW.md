# chien-dev (dev-environment-setup)

<p align="center">
  <img src="https://img.shields.io/badge/Backend-Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/Backend-Multipass-0052CC?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Multipass">
  <img src="https://img.shields.io/badge/Language-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
</p>

[English](./README.md) | [繁體中文](./README.zh-TW.md)

**chien-dev** 是一款標準化的開發環境腳手架。它支援 **容器 (DevContainer)** 與 **虛擬機 (Virtual Machine)** 雙後端，幫助你輕鬆配置與管理隔離的開發環境。

---

## 核心功能

- **雙後端支援**：在 **Docker (DevContainer)** 與 **虛擬機 (Multipass VM)** 之間無縫切換。
- **互動式建立**：透過友善的 CLI 自訂 OS 版本、開發語言與服務。
- **智慧資源偵測**：自動偵測宿主機 CPU/RAM/磁碟，提供最合適的 VM 配置建議。
- **SSH 安全自動化**：自動處理 VM 的 SSH 金鑰注入，實現免密登入。
- **環境醫生 (Doctor Check)**：內建檢查連接埠衝突與工具依賴性。

---

## 操作演示 (Demo)

![操作演示](./assets/dev_env_demo.gif)

---

## 使用方式

### 啟動前準備

- 安裝 [Docker Desktop](https://www.docker.com/products/docker-desktop/) (用於容器模式)
- 安裝 [Multipass](https://multipass.run/) (選用，用於虛擬機模式)

### 建議的第一次流程

```bash
make chien-dev doctor
make chien-dev create <名稱>
make chien-dev start <名稱> PROJECT=/專案/絕對/路徑
make chien-dev status
```

### 詳細指令行為

- `make chien-dev help`：顯示指令用法與範例。
- `make chien-dev create <name>`：建立命名環境（互動式或透過環境變數）。
- `make chien-dev start <name> PROJECT=/path`：啟動環境並將專案掛載至 `/workspace`。
- `make chien-dev status [name]`：顯示所有環境狀態或特定環境的詳細資訊。
- `make chien-dev shell <name>`：進入容器 bash (容器模式) 或顯示 SSH 登入指令 (VM 模式)。
- `make chien-dev stop <name>`：停止環境。
- `make chien-dev clean <name>`：安全地移除環境及其產生的檔案。

### 非互動模式 (適合 CI/CD)

帶入以下變數即可跳過提示：

```bash
# 建立 VM 環境並指定資源
ENV=vm VM_CPUS=4 VM_MEM=4G make chien-dev create my-node

# 在容器中安裝特定語言與資料庫
make chien-dev create my-dev LANGS=go,node DB=postgres
```

| Key | 可選值 | 預設值 |
|-----|--------|---------|
| `ENV` | `devcontainer`, `vm` | `devcontainer` |
| `OS` | `22.04`, `24.04` | `22.04` |
| `LANGS` | `go`, `node`, `python`, `java`, `php` | 無 |
| `FRONTEND` | `react`, `vue` | `none` |
| `DB` | `postgres`, `mysql`, `mongodb` | 無 |
| `BROKER` | `redis`, `rabbitmq`, `kafka` | 無 |

---

## 環境測試

啟動環境後，你可以執行以下動作驗證：

```bash
# 容器模式：
make chien-dev shell <名稱>
go version     # (或 node --version 等)

# 虛擬機模式：
# 執行 'make chien-dev status' 中顯示的 SSH 指令
ssh ubuntu@<VM_IP>
```

---

## 程式碼結構

- `scripts/commands/`：CLI 指令處理邏輯。
- `scripts/generators/`：設定產生器 (`container_render.sh`, `vm_render.sh`)。
- `scripts/modules/`：共用的 Docker、VM 與網路偵測模組。

---

## 授權條款

採用 MIT 授權條款。
