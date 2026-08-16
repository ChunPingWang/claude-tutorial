# 範例設定

一整套可直接複製到你專案的設定。

```bash
cp -r examples/project-claude/. ~/your-project/
```

## 內容

```
project-claude/
├── CLAUDE.md                              專案指示範本
├── .gitignore-snippet                     要加進 .gitignore 的行
└── .claude/
    ├── settings.json                      權限 + hooks
    ├── rules/
    │   ├── testing.md                     path-scoped rule 範例
    │   └── api-design.md
    ├── skills/
    │   ├── commit/SKILL.md                手動觸發、含 allowed-tools
    │   ├── review-pr/SKILL.md             動態 context 注入
    │   └── dep-audit/SKILL.md             context: fork 子代理執行
    ├── agents/
    │   ├── bug-hunter.md                  唯讀調查員
    │   └── test-writer.md                 測試撰寫者
    └── hooks/
        └── protect.sh                     阻擋型 PreToolUse hook
```

## 套用步驟

1. 複製檔案過去
2. 把 `.gitignore-snippet` 的內容加進你的 `.gitignore`
3. `chmod +x .claude/hooks/protect.sh`
4. 編輯 `CLAUDE.md`，換成你的專案內容（**這步不能跳過**，範本裡的指令是假的）
5. 編輯 `.claude/settings.json`，把 `pnpm` 換成你實際用的套件管理器
6. 啟動 `claude`，跑 `/context` 確認載入正常

## 注意

`settings.json` 裡的 `deny` 規則是保守起手式，請依你的專案調整。
`hooks` 預設有一條 PostToolUse 會跑 prettier——沒裝的話請先刪掉那段。
