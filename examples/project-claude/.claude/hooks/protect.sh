#!/usr/bin/env bash
# PreToolUse hook：擋下對受保護路徑的寫入。
# 退出碼 2 = 阻擋動作，並把 stderr 的訊息回饋給 Claude。
#
# 安裝後記得：chmod +x .claude/hooks/protect.sh

set -euo pipefail

# hook 的輸入是 stdin 上的一份 JSON
input=$(cat)
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

[ -z "$path" ] && exit 0

case "$path" in
  */infra/terraform/prod/*)
    echo "❌ 拒絕：$path 屬於正式環境的 Terraform 設定，變更必須走 PR 流程。" >&2
    exit 2
    ;;
  */src/generated/*)
    echo "❌ 拒絕：$path 是 codegen 產物。請改動來源 schema 後重新產生。" >&2
    exit 2
    ;;
  *.env|*.env.production|*.env.local)
    echo "❌ 拒絕：不要修改 env 檔案，請告訴我需要哪些變數，我自己來設。" >&2
    exit 2
    ;;
esac

exit 0
