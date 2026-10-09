# model-price-repo

sub2api 的远程模型定价目录（LiteLLM 格式）。

## 文件

- `model_prices_and_context_window.json`：定价数据，顶层是 `模型名 -> 定价` 的对象。
- `model_prices_and_context_window.sha256`：上面文件的 sha256。sub2api 比对它来决定是否重新下载，改 JSON 后必须同步更新（推送到 main 后 GitHub Action 会自动更新，本地也可运行 `scripts/update-hash.sh`）。

## 在 sub2api 中使用

```yaml
pricing:
  remote_url: "https://raw.githubusercontent.com/<owner>/model-price-repo/main/model_prices_and_context_window.json"
  hash_url: "https://raw.githubusercontent.com/<owner>/model-price-repo/main/model_prices_and_context_window.sha256"
```

或环境变量 `PRICING_REMOTE_URL` / `PRICING_HASH_URL`。修改这两个配置需要重启 sub2api；之后仓库内容变化会在下一次哈希检查（默认 10 分钟）自动生效。

仓库必须是公开的（sub2api 下载时不带认证）。远程目录中没有的模型，会由 sub2api 本地的 `fallback_file` 补齐，所以空目录 `{}` 也能正常使用。

## 条目格式

价格单位为 美元 / token。只有包含 `input_cost_per_token`、`output_cost_per_token` 或图片价格字段的条目才会被加载。

```json
{
  "claude-sonnet-4-20250514": {
    "litellm_provider": "anthropic",
    "mode": "chat",
    "input_cost_per_token": 3e-06,
    "output_cost_per_token": 1.5e-05,
    "cache_creation_input_token_cost": 3.75e-06,
    "cache_read_input_token_cost": 3e-07,
    "max_input_tokens": 200000,
    "max_output_tokens": 64000
  }
}
```
