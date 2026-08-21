# 06 · Settings 與權限

`settings.json` 是唯一有**強制力**的設定層。CLAUDE.md 只是建議，settings 是規則。

---

## 6.1 五層優先序

| 層級 | 位置 | 適用 |
| --- | --- | --- |
| **Managed** | macOS: `/Library/Application Support/ClaudeCode/managed-settings.json`<br>Linux: `/etc/claude-code/managed-settings.json`<br>（或由 MDM / 伺服器下發） | 全組織，**不可覆寫** |
| **Local** | `.claude/settings.local.json` | 你 + 這個 repo（gitignore） |
| **Project** | `.claude/settings.json` | 全團隊（commit） |
| **User** | `~/.claude/settings.json` | 你的所有專案 |

優先序（高→低）：

```
1. Managed settings      ← 蓋不掉
2. 命令列參數
3. .claude/settings.local.json
4. .claude/settings.json
5. ~/.claude/settings.json
```

驗證：`/status` 看「Setting sources」，`/doctor` 看有沒有無效項目。

---

## 6.2 常用設定鍵

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",

  "model": "opus",
  "availableModels": ["opus", "sonnet"],
  "agent": "code-reviewer",

  "permissions": { "allow": [], "deny": [], "ask": [] },
  "env": { "NODE_ENV": "development" },
  "hooks": {},

  "autoMemoryEnabled": true,
  "autoMemoryDirectory": "~/my-memory",
  "autoCompactEnabled": true,
  "autoCompactWindow": 500000,
  "alwaysThinkingEnabled": true,

  "cleanupPeriodDays": 20,
  "claudeMdExcludes": ["**/vendor/**/CLAUDE.md"],
  "disableBundledSkills": false,
  "defaultShell": "zsh",
  "autoUpdatesChannel": "stable",
  "attribution": { "commit": "🤖 Generated with Claude Code" },
  "askUserQuestionTimeout": "5m",
  "apiKeyHelper": "/bin/generate_api_key.sh"
}
```

| 鍵 | 說明 |
| --- | --- |
| `permissions` | 工具與檔案的 allow / deny / ask 規則（見 6.3） |
| `model` | 預設模型（也可用 `/model` 設） |
| `availableModels` | 限制可選的模型清單 |
| `agent` | 主執行緒預設使用的子代理 |
| `env` | 環境變數 |
| `hooks` | 事件掛鉤（見第 07 章） |
| `autoMemoryEnabled` | auto memory 開關（預設 true） |
| `autoMemoryDirectory` | 記憶存放位置，需絕對路徑或 `~/` 開頭 |
| `autoCompactEnabled` / `autoCompactWindow` | 自動壓縮開關與門檻（100k–1M tokens） |
| `alwaysThinkingEnabled` | 預設開啟延伸思考 |
| `cleanupPeriodDays` | 逐字稿保留天數（預設 30，最小 1，設 0 會驗證失敗）。也決定 worktree 的清掃週期 |
| `worktree.baseRef` | worktree 從哪開分支：`"fresh"`（預設，remote 預設分支）或 `"head"`（你目前的本地 HEAD）。見 [05 章 5.8](05-Subagents-子代理.md#58-worktree-隔離) |
| `claudeMdExcludes` | 略過某些 CLAUDE.md（絕對路徑 glob，各層合併） |
| `disableBundledSkills` | 關掉內建 skills |
| `disableAgentView` / `disableWorkflows` | 關閉 agent view / dynamic workflows |
| `workflowSizeGuideline` | workflow 規模建議：`small`(<5) / `medium`(<15，預設) / `large`(<50) / `unrestricted` |
| `teammateMode` | agent teams 顯示模式：`in-process`（預設）/ `auto` / `tmux` / `iterm2` |
| `crossSessionInbound` | 跨 session 收訊：`accept` / `hold` / `refuse` |
| `isolatePeerMachines` | 訊息送出本機前一律要你核准 |
| `disableArtifact` / `disableRemoteControl` / `disableClaudeAiConnectors` | 關閉對應功能 |
| `companyAnnouncements` | 啟動時顯示的公告（managed） |
| `claudeMd` | 直接把企業版 CLAUDE.md 內容寫在 managed settings 裡（**只有 managed/policy 層有效**） |
| `allowedMcpServers` / `deniedMcpServers` | MCP 名單（managed 專用） |
| `blockedMarketplaces` / `strictKnownMarketplaces` | 外掛市集限制（managed 專用） |

---

## 6.3 權限規則語法

```json
{
  "permissions": {
    "allow": [
      "Bash(npm run lint)",
      "Bash(npm run test *)",
      "Bash(git status)",
      "Bash(git diff *)",
      "Read(~/.zshrc)",
      "Write(./src/**)",
      "Skill(commit)"
    ],
    "deny": [
      "Bash(curl *)",
      "Bash(rm -rf *)",
      "Bash(git push *)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(./secrets/**)"
    ],
    "ask": [
      "Bash(git commit *)"
    ]
  }
}
```

**格式**：`工具名(pattern)`

- 工具名：`Bash`、`Read`、`Write`、`Edit`、`DeleteFile`、`WebFetch`、`Skill`、
  MCP 工具用 `mcp__server__tool`
- pattern 支援 `*` 萬用字元與 glob
- 只寫工具名（不加括號）= 該工具全部

**優先序**：`deny` > `ask` > `allow`。deny 是絕對的。

各層設定的規則會**合併**（不是覆蓋），所以企業層加的 deny 你拿不掉。

### 起手式：這幾條加了少一半彈窗

```json
{
  "permissions": {
    "allow": [
      "Bash(git status)", "Bash(git diff *)", "Bash(git log *)",
      "Bash(git branch *)", "Bash(git show *)",
      "Bash(ls *)", "Bash(cat *)", "Bash(pwd)",
      "Bash(npm test *)", "Bash(npm run lint *)", "Bash(npm run build)",
      "Read(**)"
    ],
    "deny": [
      "Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)",
      "Bash(rm -rf /*)",
      "Bash(git push --force*)"
    ]
  }
}
```

> 懶人法：跑內建的 `/fewer-permission-prompts`。
> 它會掃你的逐字稿，找出你常按「允許」的唯讀指令，自動產生排序過的白名單寫進專案設定。

---

## 6.4 權限模式

`Shift+Tab` 循環，或用 `--permission-mode` 指定：

| 模式 | 行為 |
| --- | --- |
| `default` | 依規則判定，未涵蓋的問你 |
| `acceptEdits` | 檔案編輯自動放行 |
| `plan` | **唯讀**，產出計畫供核准 |
| `auto` | 由分類器自動判定（可用 `autoMode.soft_deny` 微調） |
| `dontAsk` | 不問，但仍受 deny 規則約束 |
| `bypassPermissions` | 全部放行。**只在容器裡用** |

```bash
claude --permission-mode plan
```

`autoMode` 可以用自然語言加規則：

```json
{
  "autoMode": {
    "soft_deny": ["$defaults", "Never run terraform apply", "不要動 prod 資料庫"]
  }
}
```

---

## 6.5 環境變數

```json
{
  "env": {
    "NODE_ENV": "development",
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1"
  }
}
```

常用的 Claude Code 環境變數：

| 變數 | 用途 |
| --- | --- |
| `CLAUDE_CODE_SKIP_PROMPT_HISTORY=1` | 不寫逐字稿與 prompt 歷史 |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` | 關閉 auto memory |
| `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` | 讓 `--add-dir` 的目錄也載入 CLAUDE.md |
| `CLAUDE_CODE_NEW_INIT=1` | 啟用互動式多階段 `/init` |
| `ANTHROPIC_API_KEY` | 用 API key 而非訂閱登入 |

hook 指令裡可用的路徑變數：`${CLAUDE_PROJECT_DIR}`、`${CLAUDE_PLUGIN_ROOT}`、`${CLAUDE_PLUGIN_DATA}`。

---

## 6.6 三種情境的完整設定

### 個人開發機（`~/.claude/settings.json`）

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "theme": "dark",
  "alwaysThinkingEnabled": true,
  "cleanupPeriodDays": 14,
  "permissions": {
    "allow": [
      "Bash(git status)", "Bash(git diff *)", "Bash(git log *)",
      "Bash(ls *)", "Read(**)"
    ],
    "deny": [
      "Read(./.env)", "Read(./.env.*)",
      "Read(**/id_rsa)", "Read(**/.ssh/**)",
      "Bash(rm -rf /*)"
    ]
  }
}
```

### 團隊專案（`.claude/settings.json`，進版控）

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(pnpm test *)", "Bash(pnpm lint *)",
      "Bash(pnpm typecheck)", "Bash(pnpm build)",
      "Write(./src/**)", "Write(./tests/**)"
    ],
    "deny": [
      "Read(./.env*)", "Read(./config/secrets/**)",
      "Write(./src/generated/**)",
      "Write(./infra/terraform/prod/**)",
      "Bash(git push *)",
      "Bash(pnpm publish *)"
    ],
    "ask": ["Bash(pnpm db:migrate *)"]
  },
  "env": { "NODE_ENV": "test" },
  "claudeMdExcludes": ["**/node_modules/**/CLAUDE.md"]
}
```

### 企業（`managed-settings.json`）

```json
{
  "claudeMd": "所有 commit 前必須通過 `make lint`。\n禁止直接推 main。",
  "permissions": {
    "deny": ["Bash(curl * | sh)", "Read(/etc/**)"],
    "allowManagedPermissionRulesOnly": false
  },
  "availableModels": ["opus", "sonnet"],
  "cleanupPeriodDays": 7,
  "strictKnownMarketplaces": true
}
```

---

## 6.7 什麼該用 settings、什麼該用 CLAUDE.md

| 需求 | 放哪 |
| --- | --- |
| 擋掉某個指令 / 路徑 | settings `permissions.deny` |
| 環境變數、模型路由 | settings `env` |
| 登入方式、組織限制 | managed settings |
| 程式風格、命名慣例 | CLAUDE.md |
| 「為什麼這樣設計」的背景 | CLAUDE.md |
| 「一定要在某時機執行」 | hooks |

**settings 由 client 強制執行，Claude 決定不了。CLAUDE.md 只影響行為，不是保證。**

---

## 6.8 Workspace trust

第一次在某個資料夾啟動 Claude Code，會問你信不信任這個目錄。
信任之前，專案層 settings 裡的 hooks 不會執行。

但要注意兩個例外：
- **Skill 的 `allowed-tools` 不受 workspace trust 管**（見 [04 章 4.7](04-Skills-技能.md#47-allowed-tools免確認的權限)）
- `.mcp.json` 的專案 server 在互動模式會問你；`-p` 模式、SDK、雲端 session 不會問，直接載入

所以 clone 陌生 repo 後，跑 Claude Code 前先看一眼 `.claude/`。

---

**下一章**：[07 · Hooks 掛鉤](07-Hooks-掛鉤.md)
**官方**：<https://code.claude.com/docs/en/settings> · <https://code.claude.com/docs/en/permissions>
