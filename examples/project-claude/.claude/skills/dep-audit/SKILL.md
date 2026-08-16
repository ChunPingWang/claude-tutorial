---
name: dep-audit
description: 稽核相依套件的已知漏洞與授權相容性
disable-model-invocation: true
context: fork
background: true
---

在子代理裡執行完整的相依套件稽核（所以中間的大量輸出不會進主對話）。

步驟：

1. 讀 `package.json` 與 lockfile，區分直接相依與間接相依
2. 跑 `pnpm audit --json`
3. 檢查每個**直接**相依套件的 license
4. 交叉比對：有漏洞的套件是否有可用的修補版本

只回報以下四項，不要貼原始輸出：

- **高危/嚴重漏洞**：套件名、版本、CVE、可修補的版本
- **授權問題**：非 MIT/Apache-2.0/BSD 的直接相依套件
- **無人維護**：超過兩年沒更新的直接相依套件
- **建議動作**：依優先序排列的具體指令，例如 `pnpm up foo@^2.1.0`

沒有問題的類別直接寫「無」。
