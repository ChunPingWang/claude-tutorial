# Claude Code 使用與教學手冊

> 一本從零開始、到能自訂整套工作流的中文手冊。
> 對應版本：Claude Code **v2.1.224**（2026-08）。文中標註「需 vX.Y.Z 以上」者為版本相依功能。

---

## 這本手冊在講什麼

Claude Code 是跑在終端機（也有桌面 App、網頁版、IDE 外掛）的 AI 編碼代理。它強大的地方不在於「會寫程式」，
而在於**你可以用檔案把它客製成你團隊的樣子**：

| 你想要的東西 | 用哪個機制 | 放在哪 |
| --- | --- | --- |
| 每次都要跟 Claude 講的專案背景 | `CLAUDE.md` | 專案根目錄 |
| 只在改到某類檔案時才需要的規範 | `.claude/rules/*.md` | 專案 |
| 「幫我做 X」這種多步驟流程 | **Skills** | `.claude/skills/<name>/SKILL.md` |
| 隔離出去、不污染主對話的任務 | **Subagents** | `.claude/agents/*.md` |
| 一次跑很多代理、或讓它們互相協調 | **Agent view / teams / workflows** | 見第 11 章 |
| 權限、環境變數、模型預設 | `settings.json` | `.claude/` 或 `~/.claude/` |
| 「每次存檔後自動跑 lint」這種硬性規則 | **Hooks** | `settings.json` 的 `hooks` |
| 接外部系統（Notion、GitHub、DB） | **MCP** | `.mcp.json` / `~/.claude.json` |
| 把上面全部打包分享給團隊 | **Plugins** | `.claude-plugin/plugin.json` |

**一句話原則**：能寫成「事實」的放 CLAUDE.md，能寫成「流程」的放 Skill，
必須「一定要執行」的放 Hook，會「吃掉大量 context」的放 Subagent。

---

## 目錄

| # | 章節 | 你會學到 |
| --- | --- | --- |
| 01 | [快速上手](docs/01-快速上手.md) | 安裝、第一次對話、必知的 10 個指令與快捷鍵 |
| 02 | [檔案結構總覽](docs/02-檔案結構總覽.md) | `~/.claude/` 與專案 `.claude/` 每個檔案的用途、該不該進 git |
| 03 | [CLAUDE.md 與記憶系統](docs/03-CLAUDE-md-與記憶.md) | CLAUDE.md 寫法、載入順序、`.claude/rules/`、auto memory |
| 04 | [Skills 技能](docs/04-Skills-技能.md) | SKILL.md 全部 frontmatter 欄位、參數、子代理執行、實例 |
| 05 | [Subagents 子代理](docs/05-Subagents-子代理.md) | 什麼時候該分身、frontmatter、記憶、worktree 隔離 |
| 06 | [Settings 與權限](docs/06-Settings-與權限.md) | 五層設定優先序、permissions 規則語法、權限模式 |
| 07 | [Hooks 掛鉤](docs/07-Hooks-掛鉤.md) | 所有事件、四種 handler、退出碼語意、實用範例 |
| 08 | [MCP 與 Plugins](docs/08-MCP-與-Plugins.md) | 三種 MCP scope、安裝指令、外掛目錄結構與發佈 |
| 09 | [實戰工作流](docs/09-實戰工作流.md) | 探索→計畫→實作→驗證、大型 repo、code review、CI |
| 10 | [速查表](docs/10-速查表.md) | 指令、旗標、環境變數、疑難排解對照表 |
| 11 | [多代理與平行執行](docs/11-多代理與平行執行.md) | agent view、agent teams、dynamic workflows、跨 session 傳訊、成本 |

另有 [`examples/`](examples/) 一整套可直接複製的範例設定。

---

## 五分鐘導覽（不想讀完的話看這段）

```bash
# 1. 進到你的專案
cd ~/your-project

# 2. 啟動
claude

# 3. 讓 Claude 自己讀你的 codebase 並產生 CLAUDE.md
/init

# 4. 看看目前 context 裡載入了哪些東西
/context

# 5. 遇到不確定的大改動，先進計畫模式（Shift+Tab 切換）
```

接著做這三件事，投資報酬率最高：

1. **寫好 `CLAUDE.md`**（<200 行）：build/test 指令、目錄慣例、絕對不能做的事。
2. **把重複貼的長 prompt 變成 Skill**：`.claude/skills/<name>/SKILL.md`，之後打 `/name` 就好。
3. **設定 `permissions.allow`**：把 `npm test`、`git status` 這類安全指令加白名單，少一半的確認彈窗
   （或直接用內建的 `/fewer-permission-prompts` 幫你掃描產生）。

---

## 心智模型：一個 session 的生命週期

```
啟動 claude
   │
   ├─ 載入 managed CLAUDE.md（企業層）
   ├─ 載入 ~/.claude/CLAUDE.md（個人）+ ~/.claude/rules/*.md
   ├─ 由檔案系統根目錄往下，載入沿途每層的 CLAUDE.md / CLAUDE.local.md
   ├─ 載入 .claude/rules/*.md（無 paths: 者）
   ├─ 載入 auto memory 的 MEMORY.md（前 200 行 / 25KB）
   ├─ 載入所有 Skills 的「description」（不是全文！）
   ├─ 連線 MCP servers、啟用 Plugins
   │
   ▼
你送出 prompt
   │
   ├─ UserPromptSubmit hook 觸發
   ├─ Claude 決定要不要載入某個 Skill 全文
   ├─ 每次工具呼叫前後：PreToolUse / PostToolUse hook
   ├─ 讀到 src/api/*.ts → 該路徑的 rules 與子目錄 CLAUDE.md 此時才載入
   │
   ▼
context 快滿 → 自動壓縮（compact）
   ├─ 專案根 CLAUDE.md 會重新從磁碟注入
   ├─ 最近呼叫過的 Skills 各保留前 5,000 tokens（總預算 25,000）
   └─ 巢狀 CLAUDE.md 與 path-scoped rules 不會自動回來
```

看懂這張圖，就知道為什麼「context 越省越好」＝「東西盡量放 Skill 而不是 CLAUDE.md」。

---

## 給教學者的建議進度

- **第 1 堂（60 分）**：01 + 02 → 學員能啟動、看懂 `/context`、知道檔案放哪。
- **第 2 堂（90 分）**：03 + 04 → 每人替自己的 repo 寫一份 CLAUDE.md 和一個 Skill。
- **第 3 堂（90 分）**：06 + 07 → 設權限白名單、寫一個 PostToolUse 自動 format 的 hook。
- **第 4 堂（90 分）**：05 + 08 + 09 → 子代理、接 MCP、跑一次完整的 feature 開發流程。

---

## 官方參考

- 文件首頁：<https://code.claude.com/docs/>
- 全文索引（給 AI 讀的）：<https://code.claude.com/docs/llms.txt>
- 本手冊各章末尾都附有對應官方頁面連結。
