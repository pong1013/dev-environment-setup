# dev-environment-setup

[English](./README.md) | [繁體中文](./README.zh-TW.md)

標準化開發環境腳本，透過命名環境（例如 `go-dev`、`node-dev`）快速建立與管理 DevContainer 開發環境。

## Before Start（先安裝與準備）

開始前，請先完成以下準備：

1. 安裝 [Docker Desktop](https://www.docker.com/products/docker-desktop/)（需包含 Docker Compose v2）
2. 啟動 Docker Desktop，確認 Docker daemon 已啟用
3. 驗證必要指令可用
   ```bash
   docker --version
   docker compose version
   make --version
   ```

若你使用 Linux，請確保已安裝 `docker`、`docker compose`、`make`，並且目前使用者可直接執行 Docker 指令（不需 `sudo`）。

## 支援功能（MVP）

- 互動式初始化（選擇 Ubuntu 版本、語言組合、服務與環境名稱）
- 依環境名稱產生檔案到 `generated/envs/<name>/`
- 啟動、停止、狀態檢查、環境檢測、清理

## 使用方式

建議第一次先執行：

```bash
make chien-dev doctor
make chien-dev init <NAME>
make chien-dev start <NAME> PROJECT=/abs/path/to/repo
make chien-dev status
```

快速啟動（相容舊指令寫法）：

```bash
make chien-dev init <NAME>
make chien-dev start <NAME> PROJECT=/abs/path/to/repo
```

行為說明：

- `make chien-dev init <name>`：建立命名環境（必填名稱）
- `make chien-dev start <name> PROJECT=/abs/path/to/repo`：啟動指定環境並掛載目標專案到 `/workspace`
- `make chien-dev status`：列出所有環境狀態
- `make chien-dev status <name>`：查看單一環境狀態
- `make chien-dev shell <name>`：直接進入 workspace 容器 bash

可用子命令：

- `start <name>`：初始化（若尚未有設定）並啟動命名環境（可用 `PROJECT` 把目標專案目錄掛載到 `/workspace`）
- `init <name>`：為命名環境做互動式初始化與檔案產生
- `stop <name>`：停止指定命名環境
- `status [name]`：查看全部環境狀態或單一環境
- `shell <name>`：進入指定命名環境的 workspace 容器 bash
- `doctor`：檢查 docker / compose / make
- `clean [name]`：清除單一命名環境；若不帶名稱則清除全部環境

## 進入環境與測試

執行 `make chien-dev start <NAME> PROJECT=/abs/path/to/repo` 後，可以用以下指令進入 workspace 容器：

```bash
make chien-dev shell <NAME>
```

進入後可先跑一組快速 smoke test：

```bash
go version
node --version
git --version
```

你也可以用 Cursor/VS Code 的 Dev Container 開啟此專案：

1. 開啟 command palette(cmd + Shift + P)
2. 選擇 `Dev Containers: Reopen in Container` (先在 extension 安裝 Dev Containers)
3. 在內建 terminal 執行相同 smoke test 指令



## TODO

- [x] 建立專案命名約定（repo/CLI/config）
- [x] 完成 MVP 指令骨架（`start/init/stop/status/doctor/clean`）
- [x] 完成互動式選單並可產生 `chien-dev.yaml`
- [x] 生成 `.devcontainer` 與 `docker-compose.yml`
- [x] 補齊 README 基本用法與啟動前準備
- [ ] 擴充非互動模式（例如：`make chien-dev start OS=ubuntu:22.04 SERVICES=postgres,redis ENV_NAME=my-dev-env`）
- [ ] 新增可自訂環境名稱（啟動時用於 dev container / 服務命名）
- [ ] 設定優先序規則（CLI > `chien-dev.yaml` > 預設值）
- [ ] 將語言與 feature 模組化（profiles/features 檔案）
- [ ] 補 `project init`（`.env.example`、基本 Make targets）
- [ ] 增強 `doctor`（port 衝突、daemon 狀態、權限檢查）
- [ ] 建立測試與 CI（shellcheck + smoke tests）
- [ ] Phase 2：加入 VM backend（例如 Multipass/Vagrant）
