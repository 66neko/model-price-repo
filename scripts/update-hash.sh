#!/usr/bin/env bash
# 校验定价 JSON 并重新生成 sha256 文件。sub2api 通过比对该哈希决定是否重新下载。
set -euo pipefail

cd "$(dirname "$0")/.."
FILE="model_prices_and_context_window.json"

python3 -c "import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d, dict), 'top level must be an object'" "$FILE"
sha256sum "$FILE" | awk '{print $1}' > model_prices_and_context_window.sha256
echo "sha256: $(cat model_prices_and_context_window.sha256)"
