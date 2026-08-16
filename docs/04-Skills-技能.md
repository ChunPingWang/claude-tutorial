# 04 · Skills 技能

Skill 是 Claude Code 最重要的擴充機制。一句話：
**把你重複貼的那段長 prompt，變成一個 `/指令`。**

> 舊的「自訂 slash command」（`.claude/commands/*.md`）已經與 Skills 合併成同一套機制。
> `.claude/commands/deploy.md` 和 `.claude/skills/deploy/SKILL.md` 都會產生 `/deploy`，行為相同。
> 舊檔案照樣能用；但新的東西請寫成 Skill——它多了目錄（可放附檔）、frontmatter 控制、
> 以及讓 Claude 自動判斷何時使用的能力。

---

## 4.1 為什麼是 Skill，而不是 CLAUDE.md

| | CLAUDE.md | Skill |
| --- | --- | --- |
| 何時進 context | **每個 session，全文** | 只有 description 常駐；全文在被呼叫時才載入 |
| 成本 | 一直付 | 不用時幾乎為零 |
| 適合 | 短的事實、慣例 | 長的流程、checklist、參考資料 |

所以：**CLAUDE.md 裡某一節長成了一套流程，就該搬成 Skill。**

---

## 4.2 最小可用範例

```bash
mkdir -p .claude/skills/commit
```

```markdown
<!-- .claude/skills/commit/SKILL.md -->
---
description: 檢查變更並產生一則符合本專案規範的 commit
disable-model-invocation: true
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *) Bash(git diff *)
---

1. 跑 `git status` 和 `git diff --staged` 看清楚改了什麼
2. 若沒有 staged 內容，先問我要 stage 哪些
3. commit message 格式：`type(scope): 繁體中文說明`
   type 限定：feat / fix / refactor / test / docs / chore
4. 訊息第一行不超過 50 字
5. **不要** push
```

存檔，回到 session（Claude Code 會自動偵測，不用重啟），輸入 `/commit`。

---

## 4.3 Skill 放哪裡

| 層級 | 路徑 | 生效範圍 |
| --- | --- | --- |
| 企業 | 由 managed settings 指定 | 全組織 |
| 個人 | `~/.claude/skills/<name>/SKILL.md` | 你的所有專案 |
| 專案 | `.claude/skills/<name>/SKILL.md` | 這個專案 |
| 外掛 | `<plugin>/skills/<name>/SKILL.md` | 啟用該外掛的地方 |

**同名衝突規則**（注意方向）：

- 企業 > **個人** > **專案**。`~/.claude/skills/deploy` 會蓋掉專案的 `deploy`。
- 你的 skill 會蓋掉同名的內建 skill，但蓋不掉內建的**別名**
  （例如自訂 `code-review` 會取代 `/code-review`，但打 `/review` 仍是內建的）。
- 外掛用 `plugin-name:skill-name` 命名空間，永遠不衝突。
- `skills/` 勝過 `commands/`。

**monorepo 巢狀 skills**：工作目錄底下子目錄的 `.claude/skills/` 也會被載入——
當 Claude 讀寫該子目錄的檔案時就變成可用。同名時兩個都保留，
巢狀那個會顯示成目錄限定名，例如 `apps/web:deploy`。

---

## 4.4 Frontmatter 完整欄位

全部欄位都是選填，只有 `description` 強烈建議寫。
布林值接受 `true/false/yes/no/on/off/1/0`（大小寫不拘，需 v2.1.218+；之前只認 true/false）。

| 欄位 | 說明 |
| --- | --- |
| `name` | 顯示名稱。預設用目錄名 |
| `description` | **最重要**。做什麼 + 何時用。Claude 靠這句決定要不要載入。把關鍵用途寫在最前面——`description` + `when_to_use` 合計在清單裡會被截斷在 1,536 字元 |
| `when_to_use` | 補充觸發時機、範例句。接在 description 後面，共用那 1,536 字元額度 |
| `argument-hint` | 自動完成時顯示的參數提示，如 `[issue-number]` |
| `arguments` | 具名位置參數，供內文用 `$name` 取代。接受空白分隔字串或 YAML list |
| `disable-model-invocation` | `true` = 只有你能用 `/name` 叫它，Claude 不會自動載入。**有副作用的流程一定要設**（deploy、commit、發訊息） |
| `user-invocable` | `false` = 只有 Claude 能用，不出現在 `/` 選單。適合純背景知識 |
| `allowed-tools` | 這一輪免確認的工具。**下一則訊息就失效** |
| `disallowed-tools` | 這個 skill 啟用期間移除掉的工具。同樣下一則訊息失效 |
| `model` | 這個 skill 啟用時用的模型。只影響當前這一輪 |
| `effort` | 推理強度：`low` / `medium` / `high` / `xhigh` / `max` |
| `context` | 設 `fork` = 在獨立的子代理 context 執行 |
| `agent` | 搭配 `context: fork` 時使用哪種子代理 |
| `background` | 只在 `context: fork` 時有效。設 `false` = 當輪等它跑完（需 v2.1.218+） |
| `hooks` | 呼叫此 skill 時註冊 hooks，之後整個 session 持續有效 |

### 呼叫權限的三種組合

| frontmatter | 你能叫 | Claude 能叫 | context 佔用 |
| --- | --- | --- | --- |
| （預設） | ✅ | ✅ | description 常駐，全文在呼叫時載入 |
| `disable-model-invocation: true` | ✅ | ❌ | description **不常駐**，全文在你呼叫時載入 |
| `user-invocable: false` | ❌ | ✅ | description 常駐，全文在 Claude 呼叫時載入 |

> `disable-model-invocation: true` 額外的好處是連 description 都不佔 context。
> 純手動的流程建議都加上。

---

## 4.5 傳參數

### `$ARGUMENTS`：接全部

```markdown
---
name: fix-issue
description: 修正指定編號的 GitHub issue
argument-hint: [issue-number]
disable-model-invocation: true
---

修正 GitHub issue $ARGUMENTS：

1. 用 `gh issue view $ARGUMENTS` 讀取內容
2. 找出相關程式碼
3. 實作修正並補上測試
4. 開一個 PR，描述裡寫 `Closes #$ARGUMENTS`
```

用法：`/fix-issue 482`

### 具名參數

```markdown
---
name: convert
arguments: source target
argument-hint: [source-file] [target-format]
---

把 `$source` 轉換成 $target 格式。
```

用法：`/convert report.md pdf`

---

## 4.6 附檔：把長資料留在磁碟上

```
.claude/skills/security-review/
├── SKILL.md          ← 必要。概觀 + 導覽
├── checklist.md      ← 需要時才被讀進來
├── owasp-notes.md
└── scripts/
    └── scan.py       ← 被「執行」，不佔 context
```

在 `SKILL.md` 裡告訴 Claude 每個檔案是什麼、何時該讀：

```markdown
## 補充資料
- 完整檢查清單見 [checklist.md](checklist.md)
- OWASP 對照見 [owasp-notes.md](owasp-notes.md)
- 自動掃描：執行 `python scripts/scan.py <path>`
```

**`SKILL.md` 保持在 500 行以內**，細節都推到附檔。這就是 progressive disclosure：
入口很小，需要時才展開。

---

## 4.7 `allowed-tools`：免確認的權限

```markdown
---
name: commit
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *)
---
```

重點：

- 只在**呼叫這個 skill 的那一輪**有效，你送出下一則訊息就失效。再叫一次就再生效一輪。
- 它是**加法**：不會限制其他工具，其他工具照原本的權限設定走。
- 想要整個 session 都免確認，請改寫 `settings.json` 的 `permissions.allow`。

⚠️ **安全提醒**：workspace trust 管不到這個欄位。
專案 skill 的 `allowed-tools` 在你沒信任過的資料夾裡、在 `-p` 模式下都會生效。
**clone 別人的 repo 之後，跑 Claude Code 前先看一眼 `.claude/skills/*/SKILL.md` 的 `allowed-tools`。**

---

## 4.8 在子代理裡跑：`context: fork`

```markdown
---
name: full-audit
description: 全 repo 相依套件與安全稽核
context: fork
disable-model-invocation: true
---

掃描所有相依套件的已知漏洞，產出報告。
```

`context: fork` 會開一個子代理來跑，**它讀的一大堆檔案不會進你的主對話**，
只有最後結論回來。適合會產生大量中間輸出的任務。

預設 `background: true`（背景跑，完成時通知你）；
設 `background: false` 則當輪等結果（需 v2.1.218+）。

---

## 4.9 動態 context 注入

Skill 內文可以在載入時執行指令並塞入輸出：

```markdown
---
name: review-pr
description: Review 目前分支的變更
---

## 環境
!`git branch --show-current`

## 待審 diff
!`git diff main...HEAD`

## 你的任務
針對上面的 diff，逐項檢查……
```

每次呼叫都會重跑，所以內容是即時的。
（注意：內容變了，壓縮後重新附加時會是新的一份。）

---

## 4.10 生命週期：一個容易踩的坑

Skill 被呼叫後，**渲染後的全文會以一則訊息留在對話裡，直到 session 結束**。
Claude Code 之後不會重讀那個檔案。

這代表：

- ✅ 寫成「常駐指示」：「本次任務期間，所有新函式都要附 JSDoc」
- ❌ 不要寫成「一次性步驟」再期待它下一輪還記得順序

重複呼叫同一個 skill 且內容完全相同時，只會加一句「已載入」的提示，不會塞第二份。
內容不同（參數變了、動態 context 變了）才會再附一次全文。

壓縮後：每個被呼叫過的 skill 保留最近一次呼叫的**前 5,000 tokens**，
所有 skill 共用 **25,000 tokens** 預算，從最近呼叫的往回填。
一個 session 叫太多 skill 的話，早期的會整個被丟掉——需要的話重新叫一次。

如果 skill 看起來「第一輪之後就沒作用了」，內容通常還在，是模型選了別的做法。
解法是把 `description` 和指示寫得更強硬，或改用 hook 做硬性保證。

---

## 4.11 限制 Claude 能用哪些 Skill

用權限規則（`settings.json`）：

```json
{
  "permissions": {
    "deny": ["Skill(dangerous-deploy)"],
    "allow": ["Skill(commit)", "Skill(review-pr)"]
  }
}
```

---

## 4.12 內建 Skills

Claude Code 自帶一批可直接用的 skill（`/help` 可看）。常用的：

| Skill | 用途 |
| --- | --- |
| `/code-review` | 審查目前 diff / PR / 分支，可加 `--fix` 直接套用修正 |
| `/simplify` | 只做簡化與重用的清理，不抓 bug |
| `/security-review` | 目前分支的安全審查 |
| `/run` | 啟動並操作這個專案的 app，確認改動真的能跑 |
| `/init` | 產生 CLAUDE.md |
| `/loop` | 定期重複執行某個 prompt 或指令 |
| `/schedule` | 建立 cron 排程的雲端代理 |
| `/fewer-permission-prompts` | 掃描你的逐字稿，產生權限白名單建議 |

想關掉：`{ "disableBundledSkills": true }`。

---

## 4.13 四個實用範例

### A. 發版流程（純手動、有副作用）

```markdown
---
name: release
description: 執行版本發佈流程
disable-model-invocation: true
argument-hint: [patch|minor|major]
allowed-tools: Bash(git *) Bash(pnpm *)
---

發佈 $ARGUMENTS 版本：

1. 確認在 `main` 且 working tree 乾淨，否則中止並告訴我
2. `pnpm test && pnpm typecheck`，任一失敗就中止
3. `pnpm version $ARGUMENTS`
4. 更新 CHANGELOG.md（從上一個 tag 到 HEAD 的 commit 整理）
5. `git push --follow-tags`
6. 印出 GitHub release 的草稿內容給我，**不要**自動建立 release
```

### B. 背景知識（只有 Claude 用）

```markdown
---
name: legacy-billing-context
description: 舊版 billing 模組的運作方式與地雷。碰到 src/legacy/billing/ 時使用。
user-invocable: false
---

`src/legacy/billing/` 是 2019 年的 PHP 移植版：

- `calc.ts` 的浮點數運算刻意保留誤差，對齊舊系統。**不要「修正」它**
- 所有金額單位是「分」，不是元
- `sync.ts` 的 retry 邏輯依賴外部 cron，改動需同步改 `infra/cron/`
```

### C. 專案慣例（讓 Claude 自動載入）

```markdown
---
name: api-conventions
description: 本專案的 API 設計慣例。撰寫或修改 src/api/ 底下的端點時使用。
when_to_use: 新增 endpoint、改 request/response 格式、處理錯誤回應時
---

- 路徑用 kebab-case 複數：`/user-accounts`
- 分頁一律 cursor-based：`?cursor=&limit=`（limit 上限 100）
- 錯誤回應統一 `{ error: { code, message, details? } }`
- 所有 endpoint 都要有對應的 `*.integration.test.ts`
```

### D. 大型調查（fork 出去跑）

```markdown
---
name: dep-audit
description: 稽核所有相依套件的授權與已知漏洞
context: fork
disable-model-invocation: true
---

1. 讀 package.json 與 lockfile
2. `pnpm audit --json`
3. 檢查每個直接相依套件的 license
4. 只回報：高危漏洞清單 + 非相容授權清單 + 建議動作。不要貼原始輸出
```

---

## 4.14 疑難排解

| 症狀 | 解法 |
| --- | --- |
| Skill 不會自動觸發 | `description` 寫得更具體，加入觸發詞；或補 `when_to_use` |
| 觸發得太頻繁 | 縮小 description 範圍，或加 `disable-model-invocation: true` |
| description 被截斷 | 合計上限 1,536 字元，把最關鍵的用途寫在最前面 |
| 改了 SKILL.md 沒生效 | 一般會自動重載；外掛的 skill 要跑 `/reload-plugins` |
| 呼叫後行為沒改變 | 內容還在 context，是模型選了別的路。加強指示或改用 hook |

---

**下一章**：[05 · Subagents 子代理](05-Subagents-子代理.md)
**官方**：<https://code.claude.com/docs/en/skills>
