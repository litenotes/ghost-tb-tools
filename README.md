# ghost-tb-tools

一次性工具容器：在 Zeabur 上临时部署，用于初始化 Ghost 的 Tinybird Traffic Analytics（无需本地电脑 / 无需安装 Tinybird CLI）。

> 本 README 基于 2026-08 实测跑通的经验编写，所有命令和踩坑点均经过验证。

## 目录结构

```
ghost-tb-tools/
├── Dockerfile                  # python slim + Tinybird CLI + 保持运行
├── README.md
└── ghost-tinybird-schema/      # Ghost 官方 Tinybird schema（已实测可部署）
    ├── datasources/            # 5 个 .datasource
    ├── pipes/                  # 6 个基础 pipe（filtered_sessions*、mv_*）
    └── endpoints/              # 30 个 api_* endpoint（TYPE ENDPOINT）
```

> ⚠️ **不要改动 schema 目录结构**：
> - `pipes/` 只放 6 个基础 pipe，`endpoints/` 只放 30 个 api_*，**两个目录内容不能重复**；
> - 同一文件名若同时出现在两个目录，部署会报 `Resource names must be unique`；
> - 文件必须完整（曾遇到 `mv_hits.pipe` 被截断导致 SQL 解析失败）。
> - 如需重新获取 schema，从官方同步仓库下载：https://github.com/Tom-Ravn/Ghost_tinybird_sync/tree/main/tinybird

## 使用步骤

### 第 0 步：Tinybird 准备（5 分钟）

1. 注册 / 登录 https://tinybird.co
2. 创建 Workspace，区域选 **GCP**（`europe-west2` 或 `europe-west3`）
   > ⚠️ 不要选 AWS 区域：Zeabur 容器无法稳定解析 AWS 区域的 API 子域，部署和事件上报都会失败
3. 进入 Workspace → 左侧 **Tokens** → 复制 **"Workspace admin token"**
   （描述为 "Workspace-bound token, enables any operation over it"）
   > ⚠️ 不要复制 user-level 的 "admin xxx@outlook.com"：
   > 账号下有多个 Workspace 时，CLI 用 user-level token 会报 `could not identify the main workspace`

### 第 1 步：Zeabur 部署本仓库

1. 本仓库推送到 GitHub（公开或私有均可）
2. Zeabur → 部署新服务 → **Git 仓库** → 选择本仓库
3. 构建完成后服务进入 Running（无对外端口，仅用于命令执行）

### 第 2 步：命令执行（服务状态 → 命令）

> Zeabur 命令框不是交互式终端：**不要用 `tb login`**（非 TTY 会卡死）。
> 认证用 `TB_TOKEN` + `TB_HOST` 环境变量前缀，且 host 必须匹配 token 的区域。

**① 存 token 到文件**（关键：Web 命令框直接粘贴长 token 会被截断，导致反复 `Forbidden`）

```bash
cat > /tmp/tb.txt <<'EOF'
p.eyJ你的Workspace admin token
EOF
```

**② 验证认证**（host 按区域：europe-west3 用 `api.tinybird.co`；europe-west2 用 `api.europe-west2.gcp.tinybird.co`）

```bash
TB_TOKEN="$(cat /tmp/tb.txt)" TB_HOST='https://api.tinybird.co' tb --cloud workspace ls
```

看到 `Workspace <你的workspace名>` + ID = 通过 ✅（Workspace ID 记下来）

**③ 部署 schema**（用 `echo Y |` 喂确认；此 CLI 版本**不支持** `--yes` / `-f`）

```bash
cd /app/ghost-tinybird-schema && echo Y | TB_TOKEN="$(cat /tmp/tb.txt)" TB_HOST='https://api.tinybird.co' tb --cloud deploy
```

看到 `Deployment #1 is live!` = 成功 ✅

**④ 拿 tracker token**

```bash
TB_TOKEN="$(cat /tmp/tb.txt)" TB_HOST='https://api.tinybird.co' tb --cloud token ls
```

从列表找 **tracker**（权限为 `analytics_events.datasource:APPEND`）复制其值。

### 第 3 步：收集 4 个凭证

| 变量 | 获取方式 |
|---|---|
| `TINYBIRD_API_URL` | `https://api.tinybird.co`（europe-west3）或对应区域地址 |
| `TINYBIRD_WORKSPACE_ID` | 第 ② 步 `workspace ls` 输出中的 ID |
| `TINYBIRD_ADMIN_TOKEN` | Tinybird UI → Tokens → Workspace admin token |
| `TINYBIRD_TRACKER_TOKEN` | 第 ④ 步 `token ls` 中的 tracker |

### 第 4 步：删除临时服务

凭证拿齐后，在 Zeabur 删除本服务（临时容器只占额度）。

## 常见问题

| 问题 | 原因 / 解决 |
|---|---|
| `Forbidden: invalid user authentication` | 区域 host 不对。解码 token 中间段（`p.eyJ` 与第一个 `.` 之间）看 `host` 字段，用对应的 `TB_HOST` |
| `Error: We could not identify the main workspace` | token 不是 workspace-bound。换 Tinybird UI 里的 **Workspace admin token** |
| `Are you sure you want to continue?` 卡住 | 非 TTY 交互卡死。用 `echo Y |` 喂确认 |
| `No such option: --yes` / `-f` | 此 CLI 版本不支持这两个选项，一律用 `echo Y |` |
| `Resource names must be unique` | schema 目录结构错误：`pipes/` 与 `endpoints/` 存在同名文件，删掉重复 |
| `error parsing xxx.pipe: Single quoted string is not closed` | 文件被截断损坏。从官方同步仓库重新下载该文件 |
| `Name or service not known`（连 `api.*.aws.tinybird.co`） | AWS 区域子域 Zeabur DNS 解析不了，换 GCP 区域 Workspace |
| 重开命令框后 `could not identify the main workspace` | shell 变量丢失，用 `TB_TOKEN="$(cat /tmp/tb.txt)"` 内联读取，不依赖变量 |

## 区域与 API Host 对照

把 token 中间段丢 https://base64decode.org 解码看 `host` 字段：

| token host 字段 | TB_HOST | 从 Zeabur 容器 |
|---|---|---|
| `gcp-europe-west3` / `eu_shared` | `https://api.tinybird.co` | ✅ 稳定 |
| `gcp-europe-west2` | `https://api.europe-west2.gcp.tinybird.co` | ✅ 稳定 |
| `aws-eu-central-1` | `https://api.eu-central-1.aws.tinybird.co` | ⚠️ DNS 解析不稳定，不推荐 |
| `ap-east-aws` | `https://api.ap-east-aws.tinybird.co` | ❌ 网络不可达，勿用 |

## 安全提醒

- token 一旦泄露，立即到 Tinybird Tokens 页面点 🔄 重置轮换
- 不要把真实 token 提交进仓库 / 文档
