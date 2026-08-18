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

### 先搞清楚預設行為

**子代理預設「不會」隔離——它們跟主 session 共用同一個工作目錄。**
Claude Code 不會自動幫你開 worktree。

（唯一的例外是桌面 App：那裡每個新 **session** 會自動配一個 worktree，
但那是 session 層級，不是子代理層級。）

所以「多代理情境下還需不需要 worktree」的答案是：**需要，但情境比多數人以為的窄。**

### 判斷準則：有沒有「並行寫入」

| 情境 | 需要 worktree？ |
| --- | --- |
| 唯讀扇出（`Explore` 搜尋、review、稽核、調查） | ❌ 不用 |
| 多個代理**依序**執行 | ❌ 不用 |
| 主線寫、子代理只讀 | ❌ 不用 |
| 多個代理**同時改檔案** | ✅ 要 |
| 代理跑 git 指令（checkout / stash / commit）而其他代理還在工作 | ✅ 要 |
| 背景長跑代理，同時你自己還在主目錄改東西 | ✅ 要 |
| 平行試 N 種方案再比較 | ✅ 要 |

實務上多代理的使用有八成是第一類——找程式碼、平行 review、多視角驗證——這些完全不用 worktree。

> ⚠️ 「檔案不重疊所以不用隔離」是**不安全**的推論。
> 同一個 checkout 裡 git 的 index 與 HEAD 是共用狀態：一個代理 `git stash` 或切分支，
> 其他代理腳下的檔案就變了。build 產物、lockfile、跑著的 dev server 也一樣會撞。

### 怎麼開

固定隔離，寫進 frontmatter：

```markdown
---
name: refactorer
description: 跨多檔案的機械式重構
isolation: worktree
---
```

臨時要用，直接講：

```
用 worktree 跑這些代理
```

Agent 工具與 Workflow 腳本的 agent 呼叫也都接受 `isolation: "worktree"`。

### 三個會踩的坑

**1. 預設從 remote 的預設分支開，不是你目前的工作**

子代理 worktree 的 base 跟 `--worktree` 一樣是 `"fresh"`——
從 `origin/HEAD`（通常是 `main`）開，**你未推送的 commit 與 feature 分支狀態不在裡面**。

要基於現有工作，設定：

```json
{ "worktree": { "baseRef": "head" } }
```

| 值 | 從哪裡開分支 |
| --- | --- |
| `"fresh"`（預設） | remote 的預設分支，乾淨起點 |
| `"head"` | 你目前的本地 `HEAD`，帶著未推送的工作 |

（不能填分支名稱。要從特定分支開，得自己用 `git worktree add`。）

**2. 是全新 checkout，沒有 `node_modules`、沒有 `.env`**

gitignored 的檔案要用專案根目錄的 `.worktreeinclude` 帶進去（`.gitignore` 語法）：

```text
.env
.env.local
config/secrets.json
```

只有「符合 pattern 且本身是 gitignored」的檔案會被複製，被追蹤的檔案不會重複。
相依套件則要另外裝（叫 Claude 在 worktree 裡跑一次安裝）。

**3. 成本不是零**

每個約 200–500ms 建立時間 + 磁碟空間。清理規則：

- 子代理結束時**沒有任何改動** → 自動移除
- **有改動** → 留在磁碟上，等定期掃描處理
- 定期掃描依 `cleanupPeriodDays`，且會**跳過**還有未提交變更、未追蹤檔案或未推送 commit 的 worktree
- 代理執行期間 Claude Code 會 `git worktree lock`，避免被誤刪
- 手動清：`git worktree remove <path>`（有未提交內容要加 `--force`）

### 隔離是強制執行的

session 進入 worktree 後（不論是 `--worktree`、`EnterWorktree`、還是子代理隔離），
Claude Code 會**硬性阻擋**四類逃逸：

1. `Edit`/`Write`/`NotebookEdit` 寫到主 checkout 的路徑
2. Bash/PowerShell 的工作目錄落在主 checkout
3. 用 `git -C`、`--git-dir`、`GIT_DIR`、或先 `cd` 再跑 git 來繞路
4. 無法靜態追蹤的指令形狀（大括號展開、未引號的 heredoc）——這條不能關

這不是提醒，是 client 層的攔截。所以隔離是真的隔離。

### 建議

**預設不要開。** 先用「唯讀扇出 → 主線收斂寫入」這個模式，
它解決大部分需求且沒有 worktree 的設定成本。

等到你真的要讓多個代理**同時改檔案**時，才在那個特定 agent 上加 `isolation: worktree`，
而不是全域打開。

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
