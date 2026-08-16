# 07 · Hooks 掛鉤

Hook 是在固定的生命週期事件上執行的**外部程式**。

CLAUDE.md 說「請記得跑 lint」——Claude 可能忘記。
Hook 說「每次 Edit 之後執行 lint」——**一定會跑**。

**這是 Claude Code 裡唯一的硬性保證機制。**

---

## 7.1 事件一覽

| 事件 | 觸發時機 |
| --- | --- |
| `SessionStart` | session 開始或續接 |
| `Setup` | CI / 腳本中的一次性準備 |
| `UserPromptSubmit` | 你送出 prompt 之後、Claude 處理之前 |
| `UserPromptExpansion` | 指令展開成 prompt 時 |
| **`PreToolUse`** | 工具呼叫前（**可攔截阻擋**） |
| `PermissionRequest` | 需要權限決策時 |
| `PermissionDenied` | auto 模式拒絕了某個呼叫 |
| **`PostToolUse`** | 工具呼叫成功後 |
| `PostToolUseFailure` | 工具呼叫失敗後 |
| `PostToolBatch` | 一批平行工具呼叫全部結束後 |
| `Stop` | Claude 回應結束 |
| `StopFailure` | 因 API 錯誤而結束 |
| `SubagentStart` / `SubagentStop` | 子代理啟動 / 結束 |
| `TaskCreated` / `TaskCompleted` | 任務生命週期 |
| `TeammateIdle` | 團隊代理即將閒置 |
| `PreCompact` / `PostCompact` | context 壓縮前 / 後 |
| `CwdChanged` | 工作目錄改變 |
| `DirectoryAdded` | session 中加入新目錄 |
| `FileChanged` | 被監看的檔案在磁碟上變動 |
| `WorktreeCreate` / `WorktreeRemove` | git worktree 生命週期 |
| `Notification` | Claude Code 發出通知 |
| `MessageDisplay` | 助理訊息顯示時 |
| `InstructionsLoaded` | CLAUDE.md 或 rules 被載入（**除錯神器**） |
| `ConfigChange` | session 期間設定檔變動 |
| `Elicitation` / `ElicitationResult` | MCP 要求使用者輸入 |

九成的實務需求只會用到 `PreToolUse`、`PostToolUse`、`UserPromptSubmit`、`Stop`、`SessionStart`。

---

## 7.2 設定結構

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/format.sh",
            "timeout": 30,
            "statusMessage": "格式化中…"
          }
        ]
      }
    ]
  }
}
```

可以放在：

| 位置 | 範圍 | 可分享 |
| --- | --- | --- |
| `~/.claude/settings.json` | 所有專案 | ❌ |
| `.claude/settings.json` | 這個專案 | ✅ commit |
| `.claude/settings.local.json` | 你 + 這個專案 | ❌ |
| Managed settings | 全組織 | ✅ |
| 外掛的 `hooks/hooks.json` | 啟用外掛處 | ✅ |
| Skill / Subagent 的 `hooks:` frontmatter | session / 子代理 | ✅ |

---

## 7.3 Matcher

| 事件類型 | matcher 比對的是 |
| --- | --- |
| `PreToolUse` / `PostToolUse` | 工具名稱 |
| `SessionStart` | 啟動方式（startup / resume / clear…） |
| `SubagentStart` | 代理類型 |
| `FileChanged` | 要監看的檔名 |
| `Notification` | 通知類型 |

```json
"matcher": "Bash"                // 精確
"matcher": "Edit|Write"          // OR
"matcher": "mcp__memory__.*"     // regex
```

還有一個 `if` 欄位可以用權限規則語法進一步過濾：

```json
{ "type": "command", "if": "Bash(rm *)", "command": "./confirm-delete.sh" }
```

---

## 7.4 四（五）種 handler

### `command`（最常用）

JSON 從 stdin 進來，用退出碼與 stdout 回傳決策。

```json
{ "type": "command", "command": "jq -r '.tool_input.file_path' | xargs prettier --write", "timeout": 15 }
```

### `http`

```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks",
  "headers": { "Authorization": "Bearer $TOKEN" },
  "allowedEnvVars": ["TOKEN"]
}
```

### `mcp_tool`

```json
{ "type": "mcp_tool", "server": "my_server", "tool": "validate", "input": { "path": "${tool_input.file_path}" } }
```

### `prompt`

用一次性的 Claude 呼叫做判斷：

```json
{ "type": "prompt", "prompt": "這個指令安全嗎？$ARGUMENTS", "model": "fast" }
```

### `agent`（實驗性）

派一個子代理做驗證。

---

## 7.5 退出碼語意

| 退出碼 | 意義 |
| --- | --- |
| `0` | 成功。stdout 若是合法 JSON 就採用 |
| `2` | **阻擋**。訊息回饋給 Claude，動作被攔下 |
| 其他 | 不阻擋。JSON 輸出仍會被採用 |

輸出 JSON 可以做更細的控制（例如 `permissionDecision` 決定 allow / deny / ask）。

其他常用欄位：`"async": true` 讓 hook 在背景跑；
`"disableAllHooks": true` 一次關掉全部。

---

## 7.6 實用範例

### A. 存檔後自動格式化

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{
        "type": "command",
        "command": "jq -r '.tool_input.file_path' | grep -E '\\.(ts|tsx|js|jsx)$' | xargs -r npx prettier --write",
        "timeout": 20
      }]
    }]
  }
}
```

### B. 保護正式環境設定（阻擋型）

`.claude/hooks/protect.sh`：

```bash
#!/usr/bin/env bash
set -euo pipefail

path=$(jq -r '.tool_input.file_path // empty')

case "$path" in
  */infra/terraform/prod/*|*/.env.production)
    echo "❌ $path 是受保護的正式環境檔案，請走 PR 流程。" >&2
    exit 2      # 退出碼 2 = 阻擋
    ;;
esac
exit 0
```

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/protect.sh" }]
    }]
  }
}
```

記得 `chmod +x`。

### C. 回應結束時跑型別檢查

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "cd ${CLAUDE_PROJECT_DIR} && pnpm typecheck 2>&1 | tail -20",
        "timeout": 120,
        "statusMessage": "型別檢查中…"
      }]
    }]
  }
}
```

型別錯誤會回饋給 Claude，它會自己去修。

### D. session 開始時注入即時狀態

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "echo \"分支：$(git branch --show-current)｜未提交：$(git status --porcelain | wc -l) 個檔案\""
      }]
    }]
  }
}
```

### E. 除錯：到底載入了哪些指示檔

```json
{
  "hooks": {
    "InstructionsLoaded": [{
      "hooks": [{
        "type": "command",
        "command": "cat >> ${CLAUDE_PROJECT_DIR}/.claude/instructions.log"
      }]
    }]
  }
}
```

path-scoped rules 沒生效時，看這個 log 最快。

### F. 完成時發桌面通知（macOS）

```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "osascript -e 'display notification \"Claude 完成了\" with title \"Claude Code\"'",
        "async": true
      }]
    }]
  }
}
```

---

## 7.7 除錯

```bash
claude --debug        # 會顯示哪些 hook 匹配、退出碼、輸出
```

session 內打 `/hooks` 瀏覽目前設定的所有 hooks。

常見問題：

| 症狀 | 檢查 |
| --- | --- |
| hook 沒跑 | 資料夾信任了嗎？matcher 對嗎？腳本有執行權限嗎？ |
| 一直卡住 | 加 `timeout`；長時間的用 `"async": true` |
| 阻擋不了 | 阻擋要用退出碼 **2**，不是 1 |
| 路徑找不到 | 用 `${CLAUDE_PROJECT_DIR}` 而非相對路徑 |

---

## 7.8 什麼時候用 hook、什麼時候不用

**用 hook**：
- 「每次 X 之後都要 Y」——格式化、lint、跑測試
- 「絕對不能碰 Z」——保護正式環境
- 需要客觀事實注入——git 狀態、CI 狀態

**不要用 hook**：
- 需要判斷力的事（那是 Claude 的工作，寫進 CLAUDE.md 或 Skill）
- 很慢的操作（會拖慢每一輪）

> 小技巧：可以用 `update-config` 這個內建 skill 幫你寫 hook 設定——
> 直接說「每次改完 TypeScript 檔就自動跑 prettier」，它會產出對應的 settings.json。

---

**下一章**：[08 · MCP 與 Plugins](08-MCP-與-Plugins.md)
**官方**：<https://code.claude.com/docs/en/hooks>
