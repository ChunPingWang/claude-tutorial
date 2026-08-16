# 05 · Subagents 子代理

子代理 = **另一個有自己 context window 的 Claude**，你派任務給它，它做完只回報結論。

---

## 5.1 什麼時候該用

核心價值是**context 隔離**。

```
主對話（你在這）
   │  「找出所有還在用舊版 auth API 的地方」
   ├────────────────► 子代理
   │                    讀了 60 個檔案、跑了 20 次 grep
   │                    （這些全部在它自己的 context 裡）
   ◄──────────────── 「找到 7 處：src/a.ts:42, ...」
   │  主對話只多了這 3 行
```

**適合派給子代理**：
- 大範圍搜尋（「哪些地方用到 X」）
- 需要讀很多檔案才能回答的問題
- 獨立的 review / 稽核（獨立視角比較客觀）
- 可以平行跑的任務（一次派好幾個）

**不適合**：
- 你已經知道檔案在哪、只是要看一個值 → 自己讀就好
- 需要跟你來回確認的任務 → 子代理看不到你

---

## 5.2 定義檔放哪

| 位置 | 範圍 | 優先序 |
| --- | --- | --- |
| Managed settings | 全組織 | 1（最高） |
| `--agents` CLI 旗標 | 當前 session | 2 |
| `.claude/agents/` | 這個專案 | 3 |
| `~/.claude/agents/` | 你所有專案 | 4 |
| 外掛的 `agents/` | 啟用該外掛處 | 5（最低） |

（注意方向：跟 Skills 相反，**專案的優先序高於個人的**。）

Claude Code 會監看這兩個目錄，改動幾秒內生效，不用重啟
（例外：在一個全新目錄裡建立第一個 agent 時要重啟）。

---

## 5.3 完整 frontmatter

```markdown
---
name: code-reviewer
description: 審查程式碼品質與最佳實務。改完一批程式後使用。
tools: Read, Glob, Grep
model: sonnet
---

你是資深 code reviewer。針對變更提出具體、可執行的意見，
聚焦在正確性、安全性與可維護性。不要提風格細節（有 linter 管）。
每個問題都要指出 `檔案:行號` 並說明為什麼是問題。
```

| 欄位 | 必填 | 說明 |
| --- | --- | --- |
| `name` | ✅ | 唯一識別（小寫、連字號） |
| `description` | ✅ | **Claude 靠這句決定何時委派**。寫清楚時機 |
| `tools` | | 允許的工具；省略則繼承全部 |
| `disallowedTools` | | 要拿掉的工具 |
| `model` | | `sonnet` / `opus` / `haiku` / `fable` / 完整 model ID |
| `permissionMode` | | `default` / `acceptEdits` / `auto` / `dontAsk` / `bypassPermissions` / `plan` |
| `maxTurns` | | 最多幾輪，防跑太久 |
| `skills` | | 預先載入的 skills（**全文注入**，與主對話只載 description 不同） |
| `mcpServers` | | 這個子代理能用的 MCP servers |
| `hooks` | | 生命週期 hooks（PreToolUse / PostToolUse / Stop） |
| `memory` | | 持久記憶範圍：`user` / `project` / `local` |
| `background` | | `true` = 留在背景跑 |
| `effort` | | `low` / `medium` / `high` / `xhigh` / `max` |
| `isolation` | | `worktree` = 在獨立 git worktree 裡工作 |
| `color` | | 任務列表顯示顏色 |
| `initialPrompt` | | 當它被當成主 session 執行時，自動送出的第一輪 |

檔案的**內文就是它的 system prompt**。

---

## 5.4 怎麼叫它

```
# 自然語言
用 code-reviewer 子代理檢查我剛才的改動

# @-mention
@code-reviewer (agent) 看一下 src/payment/

# 整個 session 都用這個代理
claude --agent code-reviewer
```

Claude 也會依 `description` 自動判斷要不要委派。

---

## 5.5 內建的子代理

| 名稱 | 用途 |
| --- | --- |
| `Explore` | 唯讀的大範圍搜尋。讀片段而非整檔，用來「定位」程式碼 |
| `Plan` | 架構師，產出實作計畫、指出關鍵檔案與取捨 |
| `general-purpose` | 萬用型，複雜多步驟任務 |
| `claude-code-guide` | 回答 Claude Code / Agent SDK / Claude API 的問題 |
| `statusline-setup` | 設定狀態列 |

用 `Explore` 時記得指定廣度：「medium」或「very thorough」。

---

## 5.6 什麼會被載入子代理

這是最常誤解的地方：

| 內容 | 子代理看得到嗎 |
| --- | --- |
| CLAUDE.md | ✅ |
| 主對話的 auto memory | ❌（fork 型子代理例外，它繼承整個父對話） |
| 主對話的歷史 | ❌ 只看得到你派給它的那段 prompt |
| Skills | 只有 description；除非用 `skills:` 預載（那會注入全文） |
| 它自己的 `memory:` 目錄 | ✅（獨立的一份） |

**所以：派任務時要把必要背景寫清楚。** 子代理不知道你們剛才聊了什麼。

❌ 「照剛剛講的方式改一下」
✅ 「把 `src/auth/` 底下所有 `verifyToken()` 呼叫改成 `verifyTokenV2()`，
　　後者的第二個參數改收 options 物件（見 `src/auth/v2.ts:31`）」

---

## 5.7 持久記憶

```markdown
---
name: perf-investigator
description: 效能問題調查
memory: project
---
```

`memory` 設了之後，子代理會有自己的記憶目錄
（`agent-memory/<name>/MEMORY.md`），跨 session 累積它學到的東西。
這跟主對話的 auto memory 是**分開的兩份**。

---

## 5.8 worktree 隔離

```markdown
---
name: refactor-worker
isolation: worktree
---
```

子代理會在一個新建的 git worktree 裡工作，**不會動到你的工作目錄**。
適合派好幾個平行改檔案的任務（否則會互相衝突）。

成本：每個約 200–500ms 建立時間 + 磁碟空間。沒有實際改動的話會自動移除。
需要把 gitignored 的檔案（如 `.env`）帶進 worktree 時，寫進 `.worktreeinclude`。

---

## 5.9 平行派工

同一則訊息裡派多個獨立任務，它們會同時跑：

```
同時做這三件事：
1. 用 Explore 找出所有 API 端點的定義位置
2. 用 Explore 找出所有資料庫 migration 檔
3. 用 code-reviewer 檢查 src/payment/ 的錯誤處理
```

---

## 5.10 三個實用範例

### 唯讀的偵錯調查員

```markdown
---
name: bug-hunter
description: 給定一個 bug 現象，追出根因。只調查不修改。
tools: Read, Glob, Grep, Bash
model: opus
effort: high
---

你的任務是**只調查，不修改任何檔案**。

流程：
1. 從現象反推可能的程式路徑
2. 讀相關程式碼，追資料流
3. 用 git log / git blame 找出可疑的近期改動
4. 產出報告：
   - 根因（明確指出 `檔案:行號`）
   - 觸發條件（什麼輸入會重現）
   - 建議修法（列 2 個以上選項與取捨）

不確定時要說「不確定」，不要編。
```

### 測試撰寫者

```markdown
---
name: test-writer
description: 為指定模組補測試。要求補測試涵蓋率時使用。
tools: Read, Glob, Grep, Write, Edit, Bash
permissionMode: acceptEdits
---

為指定的模組撰寫測試：

1. 先讀現有測試，**模仿它們的風格與結構**
2. 涵蓋：正常路徑、邊界值、錯誤路徑
3. 不要測實作細節，測行為
4. 寫完一定要跑 `pnpm test` 確認通過
5. 回報：新增了哪些測試檔、涵蓋了哪些案例、有哪些刻意不測的
```

### 文件同步

```markdown
---
name: docs-sync
description: 程式改動後檢查文件是否過時
tools: Read, Glob, Grep, Edit
memory: project
---

比對程式碼與 `docs/` 的內容，找出過時的部分。

只改文件，不要改程式碼。每次改動都要說明是因為哪個程式變更。
把常見的「文件容易過時的地方」記進你的記憶，下次優先檢查。
```

---

## 5.11 子代理 vs Skill 怎麼選

| | Skill | Subagent |
| --- | --- | --- |
| context | 內容進**主對話** | 用**自己的** context |
| 適合 | 流程指示、規範 | 大量讀取、獨立調查 |
| 看得到主對話 | ✅ | ❌ |
| 能平行 | ❌ | ✅ |

**要兩者兼得**：寫一個 `context: fork` 的 Skill——
你用 `/name` 呼叫，但它在子代理裡跑。

---

**下一章**：[06 · Settings 與權限](06-Settings-與權限.md)
**官方**：<https://code.claude.com/docs/en/sub-agents>
