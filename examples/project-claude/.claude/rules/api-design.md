---
paths:
  - "src/api/**/*.ts"
---

# API 設計規範

## 路徑與命名

- 資源用 kebab-case 複數：`/user-accounts`、`/order-items`
- 巢狀最多兩層：`/orders/{id}/items` 可以，再深就開新資源

## 請求與回應

- 分頁一律 cursor-based：`?cursor=<opaque>&limit=<1..100>`，預設 limit 20
- 回應包一層：`{ data: T, meta?: { nextCursor } }`
- 錯誤統一格式：`{ error: { code, message, details? } }`
  - `code` 是穩定的機器可讀字串，例如 `EXPIRED_COUPON`
  - `message` 給人看，可以改；`code` 是契約，不能隨便改

## 必要條件

- 每個 endpoint 都要有 zod schema 做 input validation，放在同檔案上方
- 每個 endpoint 都要有對應的 `*.integration.test.ts`
- 有副作用的 endpoint（POST/PUT/DELETE）必須支援 `Idempotency-Key` header
- 新增或修改 endpoint 時，同步更新 `docs/api.md`
