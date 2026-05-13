# dev-environment-setup

[English](./README.md) | [繁體中文](./README.zh-TW.md)

標準化開發環境腳本。支援 **容器 (DevContainer)** 與 **虛擬機 (Virtual Machine)** 雙後端，用於快速建立與管理隔離的開發環境。

## Before Start（先安裝與準備）

開始前，請先完成以下準備：

1. 安裝 [Docker Desktop](https://www.docker.com/products/docker-desktop/)（需包含 Docker Compose v2）
2. 啟動 Docker Desktop，確認 Docker daemon 已啟用
3. **(選用)** 若計畫使用虛擬機環境，請安裝 [Multipass](https://multipass.run/)：
4. 驗證必要指令可用
   ```bash
   docker --version
   docker compose version
   make --version
   multipass version # 若計畫使用 VM
   ```

若你使用 Linux，請確保已安裝 `docker`、`docker compose`、`make`，並且目前使用者可直接執行 Docker 指令（不需 `sudo`）。

## 支援功能（MVP）

- 互動式建立環境（選擇後端類型、Ubuntu 版本、語言組合、服務與環境名稱）
- 支援雙後端：**DevContainer** (Docker) 與 **Virtual Machine** (Multipass)
- 依環境名稱產生檔案到 `generated/envs/<name>/`
- 啟動、停止、狀態檢查、環境檢測、清理

## 使用方式

建議第一次先執行：

```bash
make chien-dev doctor
make chien-dev create <NAME>
make chien-dev start <NAME> PROJECT=/abs/path/to/repo
make chien-dev status
```

### 虛擬機 (VM) 後端用法

若要建立虛擬機環境而非容器環境：

```bash
ENV=vm make chien-dev create my-vm
```

建立完成後，可透過 `make chien-dev status` 查看 VM IP 以及 SSH 登入指令。

### 非互動模式

帶入任意以下變數即跳過對應提示：

```bash
# 建立 VM 環境
ENV=vm make chien-dev create my-node

# 在容器中只安裝 Go
make chien-dev create my-dev LANGS=go

# 指定語言與資料庫
make chien-dev create my-dev LANGS=python,java DB=postgres
```

非互動模式支援的 KEY 一覽：

| Key | 可選值 | 未指定時 |
|-----|--------|----------|
| `ENV` | `devcontainer`, `vm` | `devcontainer` |
| `OS` | `22.04`, `24.04` | `22.04` |
| `LANGS` | `go`, `node`, `python`, `java`, `php`（逗號分隔） | 不安裝 |
| `FRONTEND` | `none`, `react`, `vue` | `none` |
| `DB` | `postgres`, `mysql`, `mongodb`（逗號分隔） | 不安裝 |
| `BROKER` | `redis`, `rabbitmq`, `kafka`（逗號分隔） | 不安裝 |
| `GO_VER`, `NODE_VER`, `PYTHON_VER`, `JAVA_VER`, `PHP_VER` | 版本字串 | LTS 預設值 |
| `PG_VER`, `MYSQL_VER`, `MONGODB_VER`, `REDIS_VER`, `RABBITMQ_VER`, `KAFKA_VER` | 版本字串 | LTS 預設值 |

> **注意**：請使用 `LANGS`（不是 `LANG`），以避免和系統的 `LANG` 環境變數衝突。

## 程式碼結構

`scripts/` 現在依後端與職責拆分：

- `scripts/commands/`：各子命令處理（`create/start/stop/status/shell/doctor/clean`）
- `scripts/generators/`：各後端檔案產生器
  - `container_render.sh`：處理 DevContainer 與 Docker Compose
  - `vm_render.sh`：處理 Multipass 的 Cloud-init
- `scripts/modules/`：共用執行模組
  - `docker.sh`：Docker/Compose 輔助函式
  - `vm.sh`：Multipass 輔助函式
  - `network.sh`：連接埠掃描與偵測
- `scripts/core/`：共用路徑與參數驗證

## TODO

- [x] 建立專案命名約定（repo/CLI/config）
- [x] 完成 MVP 指令骨架（`start/create/stop/status/doctor/clean`）
- [x] 完成互動式選單並可產生 `chien-dev.yaml`
- [x] 生成 `.devcontainer` 與 `docker-compose.yml`
- [x] 補齊 README 基本用法與啟動前準備
- [x] 擴充非互動模式（`LANGS=go,node DB=postgres make chien-dev create <name>`）
- [x] 新增可自訂環境名稱（啟動時用於 dev container / 服務命名）
- [x] 增強 `doctor`（port 衝突、daemon 狀態、權限檢查）
- [ ] 建立測試與 CI（shellcheck + smoke tests）
- [x] Phase 2：加入 VM backend (Multipass)
- [ ] Phase 2.1：建立 fake-GPU VM 並作為 Kubernetes node 加入 cluster
