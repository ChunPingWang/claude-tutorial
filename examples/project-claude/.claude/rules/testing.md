---
paths:
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "tests/**/*"
---

# 測試慣例

- 測**行為**，不測實作細節。不要斷言私有函式被呼叫幾次
- 每個 `describe` 對應一個公開函式或一個使用情境
- 測試名稱用繁體中文完整句：`it('折扣碼過期時應拒絕並回傳 EXPIRED_COUPON')`
- 一律涵蓋三類案例：正常路徑、邊界值、錯誤路徑
- 外部相依用 `tests/helpers/fakes.ts` 裡現成的 fake，不要臨時 mock 整個模組
- 需要 DB 的測試放在 `*.integration.test.ts`，用 `pnpm test:integration` 跑
- 不要寫 snapshot 測試，除非是純渲染輸出
