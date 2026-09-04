# chien-dev 專案目錄與檔案職責

本文件說明 `chien-dev` 專案的目錄配置、各檔案負責的行為，以及 CLI 指令在各模組之間的執行關係。

## 專案定位

`chien-dev` 是以 Bash 開發的開發環境管理 CLI。使用者可以建立兩種隔離環境：

- **DevContainer**：使用 Docker Compose 建立工作容器，並可選配 PostgreSQL、MySQL、MongoDB、Redis、RabbitMQ、Kafka 等服務。
- **Virtual Machine**：使用 Multipass 建立 Ubuntu VM，並透過 cloud-init 注入 SSH 公鑰。

CLI 的主要流程為：

```text
使用者執行 chien-dev
        │
        ▼
scripts/chien-dev（載入所有模組並分派命令）
        │
        ├── scripts/commands/（create、start、stop 等命令流程）
        │       │
        │       ├── scripts/core/（路徑與輸入驗證）
        │       ├── scripts/modules/（Docker、VM、網路、輸出等共用能力）
        │       └── scripts/generators/（產生 Docker、Compose、cloud-init 設定）
        │
        ▼
generated/envs/<環境名稱>/（執行後產生，不納入 Git）
```

## 目錄總覽

```text
dev-environment-setup/
├── .agents/skills/                 # Repository 專用的 AI 工作流程
├── .github/workflows/              # Push 與 PR 的自動驗證
├── assets/                         # README 使用的展示素材
├── scripts/                        # CLI 主程式與所有執行邏輯
│   ├── chien-dev                   # CLI 入口
│   ├── harness-audit.sh            # 唯讀檢查可沉澱的 Harness 回饋
│   ├── validate-skills.rb          # Canonical repository Skill YAML 驗證器
│   ├── verify.sh                   # 統一的本機與 CI 驗證入口
│   ├── commands/                   # 各子命令的流程控制
│   ├── core/                       # 基礎路徑與驗證規則
│   ├── generators/                 # 環境設定檔產生器
│   └── modules/                    # Docker、VM、網路等共用功能
├── tests/                          # Bash 測試入口與不接觸真實後端的回歸測試
├── templates/                      # 預留的靜態範本
│   ├── compose/
│   └── devcontainer/
├── generated/                      # 執行時產生的環境資料；預設不存在且被 Git 忽略
├── .gitignore
├── AGENTS.md                       # 短小、常駐的 repository 工作規則
├── install.sh
├── LICENSE
├── Makefile
├── PROJECT_STRUCTURE.md
├── README.md
└── README.zh-TW.md
```

> `generated/` 不在版本庫中；它會在第一次執行 `chien-dev create` 時建立。

## 根目錄檔案

### `README.md`

英文版專案說明，介紹功能、安裝方式、支援選項、第一次使用流程與基本目錄結構。

### `README.zh-TW.md`

繁體中文版專案說明，內容與英文版 README 對應，是中文使用者的主要操作入口。

### `install.sh`

一鍵安裝腳本，負責：

- 偵測 macOS、Linux 或其他作業系統。
- 檢查 Docker 與 Multipass 是否存在，並詢問是否自動安裝缺少的依賴。
- 將專案 clone 到 `~/.chien-dev`；若已存在則同步 `origin/main`。
- 在 `~/.local/bin/chien-dev` 建立指向 `scripts/chien-dev` 的符號連結。
- 視需要協助將 `~/.local/bin` 加入 `.zshrc` 或 `.bashrc` 的 `PATH`。

此腳本會改動使用者家目錄、可能安裝系統套件，且更新既有安裝時會以遠端 `main` 覆蓋 `~/.chien-dev` 內的內容。

### `Makefile`

提供本機開發時的簡短入口，例如：

```bash
make create my-env
make start my-env
make status
make verify
make harness-audit TRUSTED=1
```

操作型目標會把目標名稱與額外參數轉交給 `./scripts/chien-dev`。`verify` 統一執行 Bash 語法檢查、回歸測試與 repository Skill YAML／metadata 檢查；`harness-audit` 只接受明確標記為 trusted 的 checkout，並從隔離暫存目錄交付 allowlist 與遮蔽後的變更證據給唯讀 Codex。唯讀只限制修改，並不是機密資料隔離。萬用 `%` 規則用來吸收環境名稱等額外 Make target，避免 Make 將它們視為不存在的建置規則而失敗。

### `.gitignore`

忽略：

- macOS 產生的 `.DS_Store`。
- CLI 建立的整個 `generated/` 執行時目錄。

### `LICENSE`

專案的 MIT 授權條款，允許使用、複製、修改、合併、發布與再授權，並聲明軟體不附帶保固。

### `PROJECT_STRUCTURE.md`

即本文件，作為專案結構、檔案責任與執行流程的維護者導覽。

## `tests/`：回歸測試

### `tests/run.sh`

`make test` 與 `make verify` 共用的測試入口，會遞迴尋找、穩定排序並執行 `tests/` 下所有 `*_test.sh`，讓依功能分層的新增測試也會預設進入本機與 CI 驗證。

### `tests/clean_test.sh`

使用 Bash mock 驗證 `clean` 的安全界線，不會操作真實 Docker 或 Multipass 資源。涵蓋 running DevContainer、stopped DevContainer、Docker 狀態查詢失敗、確認期間環境被啟動、running VM 與 stopped VM；可透過 `make test` 執行。

## `assets/`：文件素材

### `assets/dev_env_demo.gif`

CLI 操作示範動畫，由英文與繁體中文 README 引用；不參與程式執行。

## `scripts/`：CLI 實作

此目錄包含真正會執行的 CLI 程式碼。各 `.sh` 檔不是獨立執行，而是由 `scripts/chien-dev` 依固定順序 `source` 進同一個 Bash 程序，因此函式與全域變數可以互相使用。

### `scripts/chien-dev`

CLI 主入口，負責：

- 啟用 `set -euo pipefail`，讓未處理錯誤、未定義變數與 pipeline 失敗能中止程式。
- 解析符號連結，找出實際安裝目錄，確保從 `~/.local/bin/chien-dev` 執行時仍能正確載入其他腳本。
- 依序載入 `core/`、`modules/`、`generators/` 與 `commands/`。
- 讀取第一個參數作為命令；沒有命令時預設執行 `start`。
- 將 `start`、`create`、`stop`、`status`、`doctor`、`shell`、`clean`、`help` 分派到對應的 `do_*` 函式。
- 遇到未知命令時顯示錯誤與可用命令清單。

## `scripts/core/`：基礎規則

### `scripts/core/paths.sh`

集中管理專案與生成檔路徑：

- `ROOT_DIR`：專案根目錄。
- `GENERATED_DIR`：`<專案>/generated`。
- `ENVS_DIR`：`<專案>/generated/envs`。
- `env_dir_for`：取得指定環境的目錄。
- `config_file_for`：取得環境的 `chien-dev.yaml`。
- `devcontainer_dir_for`：取得環境的 `.devcontainer/`。
- `compose_file_for`：取得環境的 `docker-compose.yml`。

其他命令應透過這些 helper 取得路徑，避免各處重複拼接。

### `scripts/core/validate.sh`

集中處理輸入驗證：

- `validate_env_name`：要求環境名稱存在，且只能由英數字、`-`、`_` 組成；第一個字元必須是英數字。
- `validate_project_path`：若有提供專案路徑，必須是已存在的絕對目錄。

驗證失敗時會記錄錯誤並以非零狀態結束。

## `scripts/commands/`：CLI 子命令

此層負責「一次完整操作」的流程編排，會組合 `core/`、`modules/` 與 `generators/` 提供的函式。

### `scripts/commands/create.sh`

實作 `chien-dev create <name>`，是主要的環境建立流程：

- 解析語言、前端框架、資料庫、訊息代理、Ubuntu 版本與 VM 資源選項。
- 支援互動模式、CLI flags 與環境變數／`KEY=value` 非互動模式。
- 前端選擇 React 或 Vue 時會自動啟用 Node.js。
- DevContainer 模式會檢查常用服務連接埠，若被占用便從預設埠開始尋找下一個可用埠。
- DevContainer 模式呼叫產生器建立 `chien-dev.yaml`、Dockerfile、`devcontainer.json` 與 `docker-compose.yml`。
- VM 模式確認 Multipass 存在、取得或建立 SSH 金鑰、產生 cloud-init，接著立即建立 VM。

目前 VM 建立流程只設定基礎 Ubuntu、SSH 與通用套件；即使非互動參數帶入語言、資料庫或 broker，這些選項也不會被安裝到 VM。相關選項目前只完整作用於 DevContainer 後端。

內部解析函式：

- `_parse_lang`：將逗號分隔的 `go,node,python,java,php` 轉為布林開關。
- `_parse_db`：解析 `postgres`、`mysql`、`mongodb`。
- `_parse_broker`：解析 `redis`、`rabbitmq`、`kafka`。

### `scripts/commands/start.sh`

實作 `chien-dev start <name>`：

- 接受 `--project`、`-p`、`PROJECT` 或 `PROJECT_PATH` 指定要掛載的專案絕對路徑。
- 找不到環境設定時，會先進入建立流程。
- VM 後端使用 `multipass start`，完成後顯示 IP。
- DevContainer 後端驗證 Docker／Compose 與專案路徑，再以獨立 Compose project name 啟動服務。
- DevContainer 未指定專案路徑時，預設掛載執行 `start` 當下的工作目錄至 `/workspace`。

### `scripts/commands/stop.sh`

實作 `chien-dev stop <name>`：

- VM 後端確認實例存在後呼叫 `multipass stop`。
- DevContainer 後端執行 `docker compose down`，停止並移除容器與網路，但保留具名資料 volume。
- 若環境設定、VM 或 Compose 檔不存在，顯示提示而不建立新資源。

### `scripts/commands/status.sh`

實作 `chien-dev status [name]`：

- 有指定名稱時，只顯示該環境。
- 未指定名稱時，掃描 `generated/envs/*` 並逐一顯示。
- VM 後端顯示 Multipass 狀態、IP 與 SSH 指令。
- DevContainer 後端將顯示工作容器與附加服務的狀態表。
- `_print_single_status` 封裝單一環境的後端判斷與輸出流程。

### `scripts/commands/doctor.sh`

實作 `chien-dev doctor`，檢查本機執行條件：

- 檢查 `docker`、`make`、`git`、`lsof`、`multipass` 是否存在；Multipass 被視為選用依賴。
- 若 Docker 已安裝，進一步確認 daemon 是否運作。
- 掃描 HTTP、HTTPS、MySQL、PostgreSQL、Redis、MongoDB、RabbitMQ、Kafka 的常見連接埠。
- 連接埠被占用時顯示程序名稱與 PID。

### `scripts/commands/shell.sh`

實作 `chien-dev shell <name>`：

- DevContainer 後端執行 `docker compose exec workspace bash`，直接進入工作容器。
- VM 後端不直接啟動 SSH，而是查詢 VM IP 並輸出 `ssh ubuntu@<IP>` 指令。
- 在操作前檢查環境設定、後端工具與必要資源是否存在。

### `scripts/commands/clean.sh`

實作 `chien-dev clean <name>`，永久清理指定環境：

- 同時檢查生成目錄與 Multipass VM，避免設定檔遺失時漏掉 VM。
- 先檢查 DevContainer 或 VM 的實際狀態；環境仍在執行或狀態無法可靠判斷時，拒絕清理並提示先執行 `stop`。
- 執行前要求使用者確認，預設答案為否。
- VM 後端刪除並 purge Multipass 實例。
- DevContainer 後端執行 `docker compose down -v --remove-orphans`，連同具名 volume 一起移除。
- 最後刪除 `generated/envs/<name>/`。

此命令會刪除容器資料 volume 或 VM，屬不可逆的資料清理操作。

## `scripts/modules/`：共用能力

### `scripts/modules/docker.sh`

封裝 Docker 相關操作：

- `ensure_dependencies`：檢查 Docker CLI 與 Docker Compose plugin。
- `compose_run`：固定使用環境名稱作為 Compose project name，並帶入該環境的 Compose 檔執行後續子命令。

### `scripts/modules/vm.sh`

封裝 Multipass 與 VM 操作：

- 檢查 Multipass、判斷 VM 是否存在、啟動、停止、刪除與 purge VM。
- 建立 VM 時套用 cloud-init、CPU、記憶體與磁碟參數。
- 透過 Multipass JSON 輸出與 `jq` 取得 VM IP、狀態。
- 在 macOS 或 Linux 偵測主機 CPU、記憶體與可用磁碟，供互動建立 VM 時參考。
- `ensure_ssh_key` 優先讀取既有 Ed25519 或 RSA 公鑰；若都不存在，詢問是否建立新的 Ed25519 金鑰。

### `scripts/modules/network.sh`

處理宿主機連接埠：

- `is_port_available`：使用 `lsof` 判斷 TCP 監聽埠是否可用。
- `find_available_port`：從指定基準埠開始遞增，找出第一個可用埠。
- `get_port_owner`：取得占用連接埠的程序名稱與 PID。

### `scripts/modules/prompt.sh`

提供互動式 CLI 元件：

- 印出標題。
- 使用已提供的名稱，或提示使用者輸入環境名稱。
- 提供單選、多選與 yes/no 問答。
- 多選輸入採 `1+2` 格式，會檢查範圍並排除重複項目。

### `scripts/modules/log.sh`

統一 CLI 訊息格式，提供一般資訊、警告、錯誤與成功訊息；警告和錯誤會輸出至 stderr，並使用 ANSI 顏色提高辨識度。

### `scripts/modules/status.sh`

產生 DevContainer 的服務狀態表：

- 透過 `docker compose config --services` 取得宣告的服務。
- 透過 `docker compose ps --format json` 取得目前容器狀態。
- 內嵌 Python 程式解析不同形式的 JSON 輸出。
- 顯示服務名稱、狀態、host/container 連接埠、容器名稱與映像名稱。
- 尚未建立的服務會標示為 `not-created`。

### `scripts/modules/help.sh`

實作 `chien-dev help` 的說明文字，集中管理命令用途、參數、版本覆寫變數與常用範例。

## `scripts/generators/`：設定產生器

### `scripts/generators/container_render.sh`

負責產生 DevContainer 相關檔案，包含三個主要函式：

- `render_config`：建立環境的 `chien-dev.yaml`，記錄後端、OS、語言、版本、服務開關與 host port。
- `render_devcontainer`：依選項動態建立 Dockerfile 與 VS Code `devcontainer.json`。Dockerfile 安裝共用工具及選定的 Go、Node.js、Python、Java、PHP；`devcontainer.json` 則加入相應的 VS Code extensions。
- `render_compose`：建立工作容器與選配服務，設定 `/workspace` 掛載、服務帳密、連接埠及持久化 volume。

選配服務的開發用預設帳密也直接寫在生成的 Compose 檔中，因此這些生成物適合本機開發，不應直接當成正式環境的安全設定。

### `scripts/generators/vm_render.sh`

提供 `render_cloud_init`，產生 Multipass 使用的 `cloud-init.yaml`：

- 設定 VM hostname。
- 建立可免密碼使用 sudo 的 `ubuntu` 使用者。
- 注入宿主機 SSH 公鑰。
- 安裝 curl、wget、git、CA 憑證與軟體來源管理工具。
- 在 `/etc/motd` 寫入環境就緒訊息。

## `templates/`：預留靜態範本

此目錄目前是未來重構用的範本草稿。實際執行 `create` 時，設定內容由 `scripts/generators/*.sh` 直接寫出，尚未讀取這些 `.tmpl` 檔。

### `templates/devcontainer/Dockerfile.tmpl`

最小 Ubuntu Dockerfile 範本，保留 `{{OS_VERSION}}` placeholder。目前不參與生成流程。

### `templates/compose/docker-compose.yml.tmpl`

最小 Compose 範本，定義 `workspace` 服務、Dockerfile 路徑、專案掛載與常駐命令。目前不參與生成流程。

## `generated/`：執行時環境資料

`generated/` 由 CLI 動態建立並被 `.gitignore` 排除。每個環境位於 `generated/envs/<name>/`。

### DevContainer 環境生成物

```text
generated/envs/<name>/
├── chien-dev.yaml                 # 環境規格與選項快照
├── docker-compose.yml             # 工作容器與選配服務
└── .devcontainer/
    ├── Dockerfile                 # 開發工具與語言 runtime 映像
    └── devcontainer.json          # VS Code Dev Containers 設定
```

- `chien-dev.yaml`：供 `start`、`stop`、`status`、`shell`、`clean` 判斷後端，並保存建立時的版本與服務資訊。
- `docker-compose.yml`：真正控制工作容器、資料庫、broker、port mapping 與 volume。
- `.devcontainer/Dockerfile`：建置 `workspace` 容器映像。
- `.devcontainer/devcontainer.json`：告訴 VS Code 使用 `workspace` 服務並在 `/workspace` 開啟專案。

### VM 環境生成物

```text
generated/envs/<name>/
├── chien-dev.yaml                 # 記錄 backend: vm 等環境資訊
└── cloud-init.yaml                # Multipass 第一次建立 VM 時使用的初始化設定
```

VM 本體由 Multipass 管理，不存放在此專案目錄；刪除這個資料夾不等同於刪除 Multipass VM，應使用 `chien-dev clean <name>` 完整清理。

## 指令與檔案責任對照

| 指令 | 命令檔 | 主要使用的共用模組／產生器 | 主要行為 |
| --- | --- | --- | --- |
| `create` | `commands/create.sh` | prompt、network、docker、vm、兩種 generator | 收集選項、產生設定並建立 VM 或準備容器環境 |
| `start` | `commands/start.sh` | validate、docker、vm | 啟動 Compose project 或 Multipass VM |
| `stop` | `commands/stop.sh` | docker、vm | 停止環境並保留持久資料 |
| `status` | `commands/status.sh` | status module、vm | 顯示容器服務表或 VM 狀態 |
| `doctor` | `commands/doctor.sh` | network、log | 檢查工具、Docker daemon 與 port 衝突 |
| `shell` | `commands/shell.sh` | docker、vm | 進入工作容器或顯示 VM SSH 指令 |
| `clean` | `commands/clean.sh` | prompt、docker、vm | 刪除容器 volume／VM 與生成檔 |
| `help` | `modules/help.sh` | 無 | 顯示 CLI 使用說明 |

## 維護時的修改位置

- 新增 CLI 子命令：在 `scripts/commands/` 建立處理函式，並在 `scripts/chien-dev` 載入與分派。
- 修改參數或互動流程：調整 `scripts/commands/create.sh`，並同步 `scripts/modules/help.sh` 與兩份 README。
- 新增語言 runtime 或 VS Code extension：修改 `scripts/generators/container_render.sh`。
- 新增資料庫或 broker：同時修改 `create.sh` 的選項解析、`container_render.sh` 的 config／Compose 生成，以及 `doctor.sh` 的 port 檢查。
- 修改環境儲存位置：集中調整 `scripts/core/paths.sh`。
- 修改 VM 初始化套件或使用者：調整 `scripts/generators/vm_render.sh`。
- 將範本系統正式接入：需重構 generators，使其讀取並替換 `templates/` 中的 placeholder；目前直接修改 `.tmpl` 不會影響輸出。
