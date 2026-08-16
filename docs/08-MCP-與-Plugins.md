# 08 · MCP 與 Plugins

前面幾章都在講「怎麼教 Claude 做事」。這章講「怎麼給 Claude 更多能力」與「怎麼分享出去」。

---

# Part 1：MCP（Model Context Protocol）

MCP 是開放標準，讓 Claude Code 連到外部工具與資料源：GitHub、Notion、Slack、
資料庫、監控系統、你自己的內部 API。

**判斷是否該接 MCP 的訊號**：你發現自己一直在從別的系統複製東西貼進對話。

---

## 8.1 三種安裝範圍

| Scope | 在哪些專案載入 | 團隊共享 | 存在哪 |
| --- | --- | --- | --- |
| **local**（預設） | 只有加它的那個專案 | ❌ | `~/.claude.json` |
| **project** | 只有這個專案 | ✅ 進版控 | 專案根的 `.mcp.json` |
| **user** | 你所有專案 | ❌ | `~/.claude.json` |

⚠️ 名詞陷阱：MCP 的 "local scope" 存在 `~/.claude.json`（家目錄），
跟一般設定的 `.claude/settings.local.json`（專案目錄）不是同一回事。

---

## 8.2 加入 server

### HTTP（最常見的遠端 server）

```bash
claude mcp add --transport http notion https://mcp.notion.com/mcp

# 帶認證 header
claude mcp add --transport http secure-api https://api.example.com/mcp \
  --header "Authorization: Bearer $TOKEN"
```

### SSE

```bash
claude mcp add --transport sse asana https://mcp.asana.com/sse
```

### stdio（本機執行的 server）

```bash
claude mcp add --transport stdio airtable \
  --env AIRTABLE_API_KEY=YOUR_KEY \
  -- npx -y airtable-mcp-server
```

`--` 之後的是實際要執行的指令與參數。

### 指定 scope

```bash
claude mcp add --transport http stripe --scope project https://mcp.stripe.com
claude mcp add --transport http stripe --scope user  https://mcp.stripe.com
```

### 檢查

```bash
claude mcp list        # 列出並顯示連線狀態：✔ Connected / ! Needs authentication / ✘ Failed
```

session 內用 `/mcp` 查看狀態、進行 OAuth 登入。

---

## 8.3 `.mcp.json` 格式（團隊共用）

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/"
    },
    "postgres": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": { "DATABASE_URL": "${DATABASE_URL}" }
    }
  }
}
```

放在專案根目錄、進版控，隊友 clone 下來就有一樣的工具。

- `type` 可用 `streamable-http` 作為 `http` 的別名（方便直接複製 server 文件的設定）。
- 互動 session 第一次使用 `.mcp.json` 的 server 時會**要求核准**。
  想重置這些選擇：`claude mcp reset-project-choices`。
- ⚠️ `claude -p`、Agent SDK、雲端 session **無法顯示核准對話框，會直接載入**。
  要確保某個 server 不被載入，用 `disabledMcpjsonServers` 設定（所有模式都有效）。

保留名稱（不能用來命名你的 server）：`workspace`、`claude-in-chrome`、`computer-use`、
`Claude Preview`、`Claude Browser`。

---

## 8.4 MCP 工具的命名

MCP 工具在 Claude Code 裡叫做 `mcp__<server>__<tool>`，例如：

```
mcp__github__create_issue
mcp__claude_ai_Notion__notion-search
```

寫權限規則時用這個名字：

```json
{
  "permissions": {
    "allow": ["mcp__github__*"],
    "deny": ["mcp__postgres__execute_write"]
  }
}
```

---

## 8.5 實務建議

- **從一個開始**：接太多 server 會塞爆 context（每個工具的 schema 都要載入）。
- **敏感 server 用 deny 規則收斂**：資料庫 server 只給讀，寫入操作 deny 掉。
- **credentials 不要進 `.mcp.json`**：用 `${ENV_VAR}` 引用環境變數。
- 遠端 server 需要 OAuth 時，跑 `/mcp` 走登入流程，token 存在 `~/.claude.json`。

---

# Part 2：Plugins 外掛

Plugin = **把 skills / agents / hooks / MCP 打包成一個可安裝、可版本化的單位。**

| | 獨立設定（`.claude/`） | Plugin |
| --- | --- | --- |
| Skill 名稱 | `/hello` | `/plugin-name:hello` |
| 適合 | 個人流程、專案客製、快速實驗 | 分享給團隊、發佈社群、版本化 |

**建議路徑**：先在 `.claude/` 裡快速迭代，穩定了再轉成 plugin。

---

## 8.6 安裝與使用

```bash
# 加入市集
claude plugin marketplace add anthropics/claude-plugins-official
/plugin marketplace add anthropics/claude-plugins-community

# 在 session 裡開管理器（瀏覽、安裝、看錯誤）
/plugin

# 開發時直接載入本機目錄（不用安裝）
claude --plugin-dir ./my-plugin
claude --plugin-dir ./my-plugin.zip
claude --plugin-dir ./a --plugin-dir ./b     # 多個

# 從 URL 載入 zip（例如 CI artifact）
claude --plugin-url https://example.com/my-plugin.zip

# 改完重新載入，不用重啟
/reload-plugins
```

`claude-plugins-official`（Anthropic 精選）第一次互動啟動時會自動註冊。

---

## 8.7 Plugin 目錄結構

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json       ← 只有這個檔案放在 .claude-plugin/ 裡！
├── skills/
│   └── deploy/SKILL.md   → /my-plugin:deploy
├── commands/             （舊式單檔指令，新專案用 skills/）
├── agents/
│   └── reviewer.md
├── hooks/
│   └── hooks.json
├── .mcp.json             MCP server 設定
├── .lsp.json             LSP server 設定（程式碼智慧）
├── monitors/
│   └── monitors.json     背景監看器
├── bin/                  啟用時加進 Bash PATH 的執行檔
├── settings.json         啟用時套用的預設設定
└── README.md
```

> ⚠️ **最常見的錯誤**：把 `skills/`、`agents/`、`hooks/` 塞進 `.claude-plugin/` 裡面。
> **只有 `plugin.json` 放那裡**，其他全部在 plugin 根目錄。

### `plugin.json`

```json
{
  "name": "my-plugin",
  "description": "團隊共用的部署與 review 工具組",
  "version": "1.0.0",
  "author": { "name": "Your Name" }
}
```

| 欄位 | 說明 |
| --- | --- |
| `name` | 唯一識別，同時是 skill 的命名空間（`/my-plugin:deploy`） |
| `description` | 在外掛管理器裡顯示 |
| `version` | 選填。有設的話，使用者只在你 bump 版本時才收到更新 |
| `author` | 選填 |

只有一個 skill 的 plugin，可以直接把 `SKILL.md` 放在根目錄，不用建 `skills/`。

---

## 8.8 快速建一個

```bash
mkdir -p my-first-plugin/.claude-plugin my-first-plugin/skills/hello
```

```json
// my-first-plugin/.claude-plugin/plugin.json
{ "name": "my-first-plugin", "description": "打招呼", "version": "1.0.0" }
```

```markdown
<!-- my-first-plugin/skills/hello/SKILL.md -->
---
description: 親切地問候使用者
disable-model-invocation: true
---

親切地問候 "$ARGUMENTS"，然後問他今天需要什麼協助。
```

```bash
claude --plugin-dir ./my-first-plugin
# session 裡：/my-first-plugin:hello Alex
```

### 更快的方式：skills 目錄外掛

```bash
claude plugin init my-tool
```

會在 `~/.claude/skills/my-tool/` 建好 manifest 與起始 `SKILL.md`，
下個 session 自動以 `my-tool@skills-dir` 載入，**不需要市集、不需要安裝**。

---

## 8.9 從 `.claude/` 遷移成 plugin

```bash
mkdir -p my-plugin/.claude-plugin
# 寫好 plugin.json 之後
cp -r .claude/skills   my-plugin/
cp -r .claude/agents   my-plugin/
cp -r .claude/commands my-plugin/
mkdir my-plugin/hooks
# 把 .claude/settings.json 裡的整個 "hooks" 物件複製到 my-plugin/hooks/hooks.json（格式相同）
claude --plugin-dir ./my-plugin
```

遷移後把原本 `.claude/` 裡的刪掉，避免重複：

- **agents**：專案/個人的定義會蓋掉同名的 plugin agent，不刪的話 plugin 版本不會生效。
- **skills**：plugin 版本有命名空間（`/my-plugin:deploy`），所以原本的 `/deploy` 和
  plugin 版本會**同時存在**，不會互相覆蓋。

---

## 8.10 進階元件

### LSP（程式碼智慧）

```json
// .lsp.json
{
  "go": {
    "command": "gopls",
    "args": ["serve"],
    "extensionToLanguage": { ".go": "go" }
  }
}
```

常見語言（TypeScript / Python / Rust）官方市集已有現成的 LSP plugin，直接裝就好。

### 背景監看器

```json
// monitors/monitors.json
[
  { "name": "error-log", "command": "tail -F ./logs/error.log", "description": "應用錯誤日誌" }
]
```

`command` 的每一行 stdout 都會變成通知送給 Claude。

### 預設設定

```json
// settings.json（plugin 根目錄）
{ "agent": "security-reviewer" }
```

目前只支援 `agent` 與 `subagentStatusLine` 兩個鍵。
設 `agent` 會讓這個 plugin 的某個 agent 成為主執行緒——等於整個改變 Claude Code 的預設行為。

---

## 8.11 發佈

```bash
claude plugin validate ./my-plugin           # 送審前必跑
claude plugin validate ./my-plugin --strict  # 警告也視為錯誤
```

發佈到社群市集：透過 claude.ai 或 Console 的表單送審
（`claude.ai/admin-settings/directory/submissions/plugins/new`
或 `platform.claude.com/plugins/submit`）。

團隊內部用的話，把市集放在私有 repo 就好。

---

## 8.12 安全

Plugin 會帶進 skills（含 `allowed-tools`）、hooks（會執行 shell）、MCP servers。
**這等同於在你的機器上執行別人的程式碼。**

- 只裝你信任來源的 plugin
- `--plugin-url` 只指向你自己控制或信任的 archive
- 企業可用 managed settings 的 `blockedMarketplaces`、`strictKnownMarketplaces`、
  `allowedChannelPlugins` 限制範圍

---

**下一章**：[09 · 實戰工作流](09-實戰工作流.md)
**官方**：<https://code.claude.com/docs/en/mcp> · <https://code.claude.com/docs/en/plugins>
