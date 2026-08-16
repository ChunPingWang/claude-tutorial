# 03 · CLAUDE.md 與記憶系統

每個 session 的 context window 都是全新的。有兩套機制把知識帶過去：

|  | **CLAUDE.md** | **Auto memory** |
| --- | --- | --- |
| 誰寫的 | 你 | Claude 自己 |
| 內容 | 指示、規範 | 它學到的模式與偏好 |
| 範圍 | 專案 / 個人 / 企業 | 每個 repo 一份（worktree 共用） |
| 載入 | 每個 session，全文 | 每個 session，`MEMORY.md` 前 200 行 / 25KB |
| 適合 | coding standard、工作流、架構 | build 指令、debug 心得、它發現的偏好 |

⚠️ **兩者都只是 context，不是強制設定。** Claude 會讀、會盡量遵守，但沒有保證。
要「絕對擋掉」某個動作，用 [PreToolUse hook](07-Hooks-掛鉤.md) 或 `permissions.deny`。

---

## 3.1 CLAUDE.md 放哪裡

依載入順序（由廣到窄）：

| 層級 | 位置 | 用途 |
| --- | --- | --- |
| **企業政策** | macOS: `/Library/Application Support/ClaudeCode/CLAUDE.md`<br>Linux/WSL: `/etc/claude-code/CLAUDE.md`<br>Windows: `C:\Program Files\ClaudeCode\CLAUDE.md` | 公司規範、資安政策。**無法被個人設定排除** |
| **個人** | `~/.claude/CLAUDE.md` | 你的跨專案偏好 |
| **專案** | `./CLAUDE.md` 或 `./.claude/CLAUDE.md` | 團隊共用，進版控 |
| **本機** | `./CLAUDE.local.md` | 你的專案私人設定，要 gitignore |

**載入規則**：Claude Code 從你的工作目錄一路往上走到檔案系統根，
沿途每層的 `CLAUDE.md` 與 `CLAUDE.local.md` 全部**串接**（不是覆蓋）。
順序由根往下，所以離你啟動位置越近的越晚被讀到。

工作目錄**底下**子目錄的 CLAUDE.md 不會在啟動時載入——
只有當 Claude 讀到那個子目錄的檔案時才會被帶進來（monorepo 很吃這個特性）。

---

## 3.2 怎麼寫一份好的 CLAUDE.md

### 三個硬性原則

**1. 200 行以內。** 越長越吃 token，而且遵循率反而下降。

**2. 具體到可以驗證。**

| ❌ | ✅ |
| --- | --- |
| 「把程式碼格式化好」 | 「用 2 空格縮排」 |
| 「記得測試」 | 「commit 前跑 `npm test`」 |
| 「檔案要整理好」 | 「API handler 放在 `src/api/handlers/`」 |

**3. 不要自相矛盾。** 兩條規則衝突時，Claude 會隨便挑一條。定期回頭清理。

### 什麼時候該往裡面加東西

- Claude 同一個錯誤犯了第二次
- code review 抓到「它早該知道」的問題
- 你這個 session 又打了跟上個 session 一樣的更正
- 新同事需要同樣的背景才能上手

### 什麼**不該**放進去

- 它讀 codebase 就能推出來的（目錄結構、相依套件清單、架構總覽）
- 多步驟流程 → 改放 [Skill](04-Skills-技能.md)
- 只跟某一區程式相關的 → 改放 [path-scoped rule](#35-claudeules-拆分大型指示)

> `/doctor` 有「trim 檢查」（需 v2.1.206+），會自動幫你標出 CLAUDE.md 裡
> 可以刪掉的推導性內容，保留真正有價值的坑與慣例。

### 範本

```markdown
# 專案：付款服務 API

## 常用指令
- 開發：`pnpm dev`
- 測試：`pnpm test`（單檔：`pnpm test -- payment.test.ts`）
- 型別檢查：`pnpm typecheck`
- Lint：`pnpm lint --fix`

## 架構
- `src/api/` HTTP handler，薄層，不放商業邏輯
- `src/domain/` 商業邏輯，純函式，不碰 IO
- `src/infra/` DB、外部 API client
- 依賴方向只能是 api → domain → infra，反向即為錯誤

## 慣例
- 一律用 pnpm，**不要**用 npm 或 yarn
- 錯誤用 `AppError`（`src/errors.ts`），不要直接 throw Error
- DB migration 用 `pnpm db:migrate:create <name>` 產生，不要手寫檔名

## 禁區
- 不要改 `src/generated/`（由 codegen 產出）
- 不要動 `infra/terraform/prod/`
- 沒有我明確要求，不要執行 `git push`

## 提交前必做
1. `pnpm typecheck && pnpm test`
2. commit message 用繁體中文，格式 `type(scope): 說明`
```

---

## 3.3 `@` 匯入語法

CLAUDE.md 可以用 `@path/to/file` 把別的檔案拉進來。被匯入的檔案在**啟動時就展開載入**。

```markdown
專案總覽見 @README，可用指令見 @package.json。

# 額外指示
- git 流程 @docs/git-instructions.md
- 個人偏好 @~/.claude/my-project-instructions.md
```

規則：
- 相對路徑是相對於**含有這行的檔案**，不是工作目錄。
- 可以遞迴匯入，最多 **4 層**。
- 反引號內的不會被當成匯入：`` `@README` `` 是純文字，`@README` 才會匯入。
- ⚠️ **匯入不會省 context**——被匯入的檔案一樣全文進 context。它只幫你組織，不幫你減量。
- 專案 CLAUDE.md 匯入專案目錄外的檔案（例如家目錄）時，第一次會跳出核准對話框。
  這是防止別人在共用 repo 裡塞奇怪的匯入。

### 與 AGENTS.md 共存

Claude Code 只讀 `CLAUDE.md`。如果你的 repo 已經有給別的 agent 用的 `AGENTS.md`：

```markdown
<!-- CLAUDE.md -->
@AGENTS.md

## Claude Code 專屬
`src/billing/` 底下的改動一律先用 plan mode。
```

或直接 symlink（Windows 需要管理員權限，建議改用上面的匯入）：

```bash
ln -s AGENTS.md CLAUDE.md
```

`/init` 會順便讀 Cursor rules（`.cursor/rules/`、`.cursorrules`）和
Copilot（`.github/copilot-instructions.md`）並融合進去。
另有 `/import` 指令（需 v2.1.213+）可以把其他 coding agent 的完整設定搬過來。

---

## 3.4 HTML 註解 = 免費的維護筆記

區塊級 HTML 註解會在注入 context **之前**被剝除：

```markdown
<!-- 2026-03 update：這條是因為 issue #482，之後 v3 API 上線可以刪 -->
- 呼叫 `/v2/charge` 時一定要帶 `idempotency_key`
```

註解給人看，不花 token。（程式碼區塊內的註解會保留。）

---

## 3.5 `.claude/rules/`：拆分大型指示

CLAUDE.md 超過 200 行時，把主題拆到 `.claude/rules/`：

```
your-project/.claude/
├── CLAUDE.md
└── rules/
    ├── code-style.md
    ├── testing.md
    ├── security.md
    └── frontend/react.md      ← 子目錄會被遞迴掃描
```

沒有 `paths:` 的 rule，跟 `.claude/CLAUDE.md` 同等級，**啟動時就載入**。

### Path-scoped rules（真正能省 context 的做法）

加上 `paths:` frontmatter，這條規則只有在 Claude 讀到符合的檔案時才進 context：

```markdown
---
paths:
  - "src/api/**/*.ts"
  - "src/**/*.{ts,tsx}"
---

# API 開發規範

- 所有端點必須做 input validation
- 錯誤格式統一用 `ErrorResponse`
- 要附上 OpenAPI 文件註解
```

| Pattern | 匹配 |
| --- | --- |
| `**/*.ts` | 任意目錄下的所有 TS 檔 |
| `src/**/*` | `src/` 下所有檔案 |
| `*.md` | 專案根目錄的 md |
| `src/components/*.tsx` | 特定目錄的 React 元件 |

注意事項：
- 大括號展開有預算上限（單條 rule 共 1,000 個展開後 pattern、4 MiB），超過就不展開、等於不匹配。
- 檔名裡有字面 `[` 要跳脫成 `\[`，否則被當成 bracket expression。
- 只在 Claude **讀取檔案**時觸發，不是每次工具呼叫。

### 個人層 rules

`~/.claude/rules/` 的規則套用到所有專案，且**先於**專案 rules 載入（所以專案的優先序較高）。

### 跨專案共用

```bash
ln -s ~/shared-claude-rules .claude/rules/shared
ln -s ~/company-standards/security.md .claude/rules/security.md
```

symlink 會被正常解析，循環參照有防護。

---

## 3.6 Auto memory：Claude 自己的筆記本

預設**開啟**。Claude 在工作過程中會自己判斷什麼值得記下來——
build 指令、debug 發現、你的偏好——不需要你動手。

### 存在哪

```
~/.claude/projects/<project>/memory/
├── MEMORY.md          ← 索引，每個 session 載入前 200 行 / 25KB
├── debugging.md       ← 主題檔，需要時才由 Claude 讀取
└── api-conventions.md
```

`<project>` 由 git repo 推導，所以同 repo 的所有 worktree 共用一份。
**這是機器本機的，不會跨機器同步。**

`MEMORY.md` 只是索引：Claude 會把細節搬到主題檔，保持索引精簡。
超過限制時寫入仍會成功，但超出的部分下次載入就被丟掉，Claude Code 會回報錯誤要它重寫索引。

保留期掃描（`cleanupPeriodDays`）**會跳過** memory 目錄，記憶不會被自動清掉。

### 怎麼控制

```json
// 單一專案關閉
{ "autoMemoryEnabled": false }

// 換個位置存
{ "autoMemoryDirectory": "~/my-memory-dir" }
```

或環境變數 `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`，或 `/memory` 裡的開關。

### 檢視與編輯

```
/memory      → 列出所有記憶檔，選一個用編輯器開啟
```

全部是純 markdown，你可以隨意改、隨意刪。看到介面顯示
「Saved 2 memories」「Recalled 2 memories」就是它在讀寫這個目錄。

寫入時若檔案有 YAML frontmatter，Claude Code 會自動補上 `modified` 時間戳（需 v2.1.214+），
讓你和它自己都知道這條記憶有多新。

### 「記住這件事」

直接說就好：

```
記住：API 測試需要本機跑一個 Redis
永遠用 pnpm，不要用 npm
```

→ 存進 auto memory。

想寫進 CLAUDE.md（團隊共用）要明講：

```
把「永遠用 pnpm」加到 CLAUDE.md
```

---

## 3.7 大型 monorepo 的處理

其他團隊的 CLAUDE.md 被撈進來時，用 `claudeMdExcludes` 排除：

```json
// .claude/settings.local.json
{
  "claudeMdExcludes": [
    "**/monorepo/CLAUDE.md",
    "/Users/me/monorepo/other-team/.claude/rules/**"
  ]
}
```

pattern 比對的是**絕對路徑**，各層設定的陣列會合併。
企業政策的 CLAUDE.md 排除不掉（這是刻意的）。

---

## 3.8 疑難排解

### 「Claude 沒照我的 CLAUDE.md 做」

CLAUDE.md 是接在 system prompt 之後的**使用者訊息**，不是 system prompt 本身，
所以沒有強制力。依序檢查：

1. `/context` → **Memory files** 裡有沒有你那個檔案？沒有的話 Claude 根本看不到。
2. 檔案位置對不對？（見 3.1）
3. 指示夠不夠具體？「用 2 空格縮排」 > 「格式化好」
4. 有沒有跟別的 CLAUDE.md 打架？

如果這件事「必須在某個時間點一定發生」（每次 commit 前、每次編輯後），
那它根本不該是 CLAUDE.md，而是 [hook](07-Hooks-掛鉤.md)。

> 除錯技巧：用 `InstructionsLoaded` hook 記錄到底載入了哪些指示檔、什麼時候載入、為什麼。

### 「`/compact` 之後指示不見了」

| 內容 | 壓縮後是否保留 |
| --- | --- |
| 專案根目錄 CLAUDE.md | ✅ 會從磁碟重讀並重新注入 |
| 巢狀子目錄的 CLAUDE.md | ❌ 要等下次讀到那個目錄的檔案 |
| 有 `paths:` 的 rules | ❌ 要等下次匹配到檔案 |
| 只在對話中講過的話 | ❌ 消失 |
| 呼叫過的 Skills | ⚠️ 各保留前 5,000 tokens，總預算 25,000，從最近的往回填 |

結論：重要的事情寫進檔案，不要只用嘴巴講。

### 「CLAUDE.md 太肥了」

跑 `/doctor` 讓它建議刪什麼，或用 path-scoped rules 拆開。
注意 `@` 匯入**不會**減少 context，只是幫你分檔。

---

**下一章**：[04 · Skills 技能](04-Skills-技能.md)
**官方**：<https://code.claude.com/docs/en/memory>
