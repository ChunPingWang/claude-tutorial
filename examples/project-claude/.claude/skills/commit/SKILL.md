---
name: commit
description: 檢查目前變更並產生一則符合本專案規範的 commit
disable-model-invocation: true
allowed-tools: Bash(git status) Bash(git diff *) Bash(git add *) Bash(git commit *) Bash(git log *)
---

產生 commit：

1. 跑 `git status` 與 `git diff --staged` 看清楚實際改了什麼
2. 若沒有 staged 內容，先跑 `git diff` 看未暫存的變更，問我要 stage 哪些
3. 跑 `git log -5 --oneline` 參考近期訊息風格
4. commit message 格式：`type(scope): 繁體中文說明`
   - type 限：`feat` / `fix` / `refactor` / `test` / `docs` / `chore`
   - scope 用模組名，例如 `api`、`payment`、`ui`
   - 第一行不超過 50 字
5. 改動涉及多個不相關的邏輯時，**拆成多個 commit**，不要混在一起
6. 說明「為什麼」而不只是「改了什麼」——「改了什麼」看 diff 就知道
7. **不要** push
