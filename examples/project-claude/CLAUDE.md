<!-- 範本：請替換成你專案的真實內容。目標 200 行以內。 -->

# 專案：<你的專案名稱>

<一句話說明這個服務做什麼、給誰用。>

## 常用指令

- 開發伺服器：`pnpm dev`
- 全部測試：`pnpm test`
- 單一測試檔：`pnpm test -- path/to/file.test.ts`
- 型別檢查：`pnpm typecheck`
- Lint 並修正：`pnpm lint --fix`
- 建置：`pnpm build`

## 架構

- `src/api/` — HTTP handler。薄層，只做參數解析與回應組裝，不放商業邏輯
- `src/domain/` — 商業邏輯。純函式，不做 IO
- `src/infra/` — DB、外部 API client、快取
- `src/generated/` — codegen 產物

依賴方向只能是 `api → domain → infra`。反向即為設計錯誤。

## 慣例

- 套件管理器一律 **pnpm**，不要用 npm 或 yarn
- 錯誤用 `AppError`（見 `src/errors.ts`），不要直接 `throw new Error()`
- 金額一律用整數「分」為單位，不用浮點數
- DB migration 用 `pnpm db:migrate:create <name>` 產生，不要手寫檔名
- 測試檔放在被測檔案旁邊，命名 `<name>.test.ts`

## 禁區

- 不要修改 `src/generated/`（由 codegen 產出，改了會被覆蓋）
- 不要修改 `infra/terraform/prod/`
- 沒有我明確要求，不要執行 `git push`
- 不要新增相依套件，需要的話先問我

## 提交前必做

1. `pnpm typecheck && pnpm test`
2. commit message 用繁體中文，格式 `type(scope): 說明`
   type 限：feat / fix / refactor / test / docs / chore

<!-- 維護筆記（不會進 Claude 的 context）：
     這個檔案的規則若超過 200 行，請把主題拆到 .claude/rules/ 並加上 paths: -->
