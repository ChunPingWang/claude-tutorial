---
name: review-pr
description: 審查目前分支相對於 main 的所有變更
disable-model-invocation: true
allowed-tools: Bash(git *) Read Grep Glob
---

## 目前分支

!`git branch --show-current`

## 變更檔案

!`git diff --stat main...HEAD`

## 完整 diff

!`git diff main...HEAD`

---

## 你的任務

針對上面的 diff 做 review。按嚴重度排序回報，每一項都要：

- 指出 `檔案:行號`
- 說明**具體會出什麼錯**（什麼輸入 → 什麼結果），不要只說「這樣不好」
- 給出修法

檢查重點（依序）：

1. **正確性**：邊界條件、null/undefined、非同步競態、錯誤路徑沒處理
2. **安全性**：注入、權限檢查缺漏、敏感資料外洩到 log
3. **契約破壞**：改到了 API 回應格式、錯誤 code、DB schema
4. **測試缺口**：新增的分支邏輯有沒有對應測試

不要報：程式風格（linter 管的）、個人偏好、「可以考慮未來重構」這類非具體問題。

沒有發現問題就直說沒有，不要湊數。
