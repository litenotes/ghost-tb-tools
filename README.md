# ghost-tb-tools

一次性工具容器：在 Zeabur 上临时部署，用于初始化 Ghost 的 Tinybird Traffic Analytics。

包含：
- `Dockerfile`：python slim + Tinybird CLI + 保持运行
- `ghost-tinybird-schema/`：Ghost 官方 Tinybird schema（datasources / pipes / endpoints，共 43 个文件）

## 使用步骤（详见《Zeabur 部署 Ghost Traffic Analytics 指南》Part 1 备选方案）

1. 本仓库推到 GitHub（公开或私有均可）
2. Zeabur → 部署新服务 → Git 仓库 → 选择本仓库
3. 服务启动后：服务状态 → 命令 → 逐条执行（`p.eyJ...` 换成你在 Tinybird UI 创建的 admin token）：
   ```bash
   pwd && ls                                    # 确认 /app 下有 ghost-tinybird-schema
   TB_TOKEN=p.eyJxxx tb --cloud workspace ls    # 验证 token，顺带拿 Workspace ID
   cd /app/ghost-tinybird-schema && TB_TOKEN=p.eyJxxx tb --cloud deploy
   ```
4. 凭证获取：去 Tinybird 网页 UI → Tokens 页面复制
   - `workspace admin token`（Admin，Ghost 用）
   - `tracker`（APPEND，traffic-analytics 用）
   - API 地址与 Workspace ID 见流程文档
5. 用完后删除该临时服务

> 注意：Zeabur 的「命令执行」不是交互式终端，所以用 `TB_TOKEN=` 环境变量前缀
> 认证（CLI 全局选项 `--token` 默认取 TB_TOKEN 环境变量），不要用交互式的 `tb login`。
