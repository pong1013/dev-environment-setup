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

## 安裝與使用

### 1. 安裝 (全域可用)

安裝 `chien-dev` 最簡單的方式是透過我們的一鍵安裝腳本：

```bash
curl -fsSL https://raw.githubusercontent.com/pong1013/dev-environment-setup/main/install.sh | bash
```
*(腳本會自動偵測你的作業系統，並詢問是否幫你安裝缺少的 Docker 或 Multipass)。*

### 2. 啟動前準備

如果你在安裝過程中跳過了依賴自動安裝，請手動安裝以下軟體：
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (用於容器模式)
- [Multipass](https://multipass.run/) (選用，用於虛擬機模式)

### 3. 建議的第一次流程

```bash
chien-dev doctor
chien-dev create <名稱>
chien-dev start <名稱> PROJECT=/專案/絕對/路徑
chien-dev status
```

### 詳細指令行為

- `chien-dev help`：顯示指令用法與範例。
- `chien-dev create <name>`：建立命名環境（互動式或透過環境變數）。
- `chien-dev start <name> PROJECT=/path`：啟動環境並將專案掛載至 `/workspace`。
- `chien-dev status [name]`：顯示所有環境狀態或特定環境的詳細資訊。
- `chien-dev shell <name>`：進入容器 bash (容器模式) 或顯示 SSH 登入指令 (VM 模式)。
- `chien-dev stop <name>`：停止環境。
- `chien-dev clean <name>`：安全地移除環境及其產生的檔案。

### 非互動模式 (適合 CI/CD)

帶入以下變數即可跳過提示：

```bash
# 建立 VM 環境並指定資源
ENV=vm VM_CPUS=4 VM_MEM=4G chien-dev create my-node

# 在容器中安裝特定語言與資料庫
chien-dev create my-dev LANGS=go,node DB=postgres
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
chien-dev shell <名稱>
go version     # (或 node --version 等)

# 虛擬機模式：
# 執行 'chien-dev status' 中顯示的 SSH 指令
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
