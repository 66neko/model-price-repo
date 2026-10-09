# model-price-repo

sub2api 的远程模型定价目录（LiteLLM 格式）。

## 文件

- `model_prices_and_context_window.json`：定价数据，顶层是 `模型名 -> 定价条目` 的对象。
- `model_prices_and_context_window.sha256`：上面文件的 sha256。sub2api 比对它来决定是否重新下载，改 JSON 后必须同步更新（推送到 main 后 GitHub Action 会自动更新，本地也可运行 `scripts/update-hash.sh`）。

## 在 sub2api 中使用

```yaml
pricing:
  remote_url: "https://raw.githubusercontent.com/66neko/model-price-repo/main/model_prices_and_context_window.json"
  hash_url: "https://raw.githubusercontent.com/66neko/model-price-repo/main/model_prices_and_context_window.sha256"
```

或环境变量 `PRICING_REMOTE_URL` / `PRICING_HASH_URL`。修改这两个配置需要重启 sub2api；之后仓库内容变化会在下一次哈希检查（默认 10 分钟）自动生效。

- 仓库必须公开（sub2api 下载时不带认证）。
- 文件里至少要有一个有效条目，否则整份目录被视为无效。
- 本目录中**没有**的模型由 sub2api 本地 `fallback_file` 补齐；本目录中**有**的模型会整条替换 fallback 里的同名条目（不是逐字段合并），所以写一个模型就要把它需要的价格字段写全。

## 条目格式

所有价格单位都是 **美元 / token**（按次的字段除外）。换算：`$3 / 百万 token` 写作 `3e-06`。

```json
{
  "model-name": {
    "litellm_provider": "openai",
    "mode": "chat",
    "input_cost_per_token": 2e-06,
    "output_cost_per_token": 1e-05,
    "cache_read_input_token_cost": 2e-07
  }
}
```

### 模型名

- 用小写。sub2api 查价时先把请求的模型名转成小写再精确匹配；含大写的键只能靠较慢的模糊匹配命中。
- 末尾的 8 位日期（如 `-20250219`）在模糊匹配时会被忽略，例如请求 `claude-opus-5-20260101` 也能命中 `claude-opus-5`。

### 元信息

| 字段 | 作用 |
| --- | --- |
| `litellm_provider` | 提供商：`anthropic` / `openai` / `xai` / `zai` 等。后台"同步模型"按它筛选；`xai` 的长上下文阈值为"达到即进高档"，其他提供商为"严格大于"。 |
| `mode` | `chat` 等。写 `image_generation` 时，后台渠道定价默认按图片（按次）模式展示和同步。 |

### 基础计费项

条目至少要有 `input_cost_per_token`、`output_cost_per_token` 或任一图片价格字段之一，否则整条被忽略。

| 字段 | 含义 |
| --- | --- |
| `input_cost_per_token` | 输入（未命中缓存） |
| `output_cost_per_token` | 输出（含推理 token） |
| `cache_read_input_token_cost` | 缓存读取（命中缓存的输入） |
| `cache_creation_input_token_cost` | 缓存写入（Anthropic 5 分钟缓存，或 OpenAI 显式缓存写入） |
| `cache_creation_input_token_cost_above_1hr` | 1 小时缓存写入。只有它大于 5 分钟价时才会分开计费，否则全部按 5 分钟价 |

没写的计费项按 0 计。例如只写了 `cache_read_input_token_cost` 而没写 `cache_creation_input_token_cost`，缓存写入就不收费。

免费模型要显式写 0（如 `glm-4.7-flash`），不能整条留空，否则条目会被忽略并回落到 fallback。

### 分时计价（峰谷价）

本目录无法表达按时段变化的价格。DeepSeek 这类有峰谷价的模型，目录里统一写**高峰价**。如需谷时折扣，在 sub2api 后台渠道的"分时倍率"里配置（如谷时 ×0.5）。

### 服务档（priority / flex / batch）

服务档后缀直接加在对应字段后面：

| 后缀 | sub2api 中的效果 |
| --- | --- |
| `_priority` | 请求 `service_tier=priority/fast` 时使用；`input_` / `output_` / `cache_read_` / `cache_creation_` 四项都支持。没写时按标准价 ×2。 |
| `_flex` | 目前不从目录读取。flex 请求统一按标准价 ×0.5（可在渠道里改倍率）。 |
| `_batches` | 目前不从目录读取，保留作参考。 |

```json
"input_cost_per_token": 2e-06,
"input_cost_per_token_priority": 4e-06,
"input_cost_per_token_flex": 1e-06,
"input_cost_per_token_batches": 1e-06
```

### 分段计价（长上下文）

输入 token 数超过阈值后，**整个请求**按高档价格计费。有两种写法，任选其一。

**写法一：阈值 + 倍率（推荐）**

```json
"input_cost_per_token": 2e-06,
"output_cost_per_token": 1e-05,
"long_context_input_token_threshold": 272000,
"long_context_input_cost_multiplier": 2.0,
"long_context_output_cost_multiplier": 1.5
```

超过 272k 后：输入 = 2e-06 × 2.0，输出 = 1e-05 × 1.5，缓存读取 / 写入跟随输入倍率。

**写法二：高档绝对价**

字段名格式为 `<基础字段>_above_<N>k_tokens`，sub2api 会换算成"阈值 + 倍率"：

```json
"input_cost_per_token": 2e-06,
"input_cost_per_token_above_200k_tokens": 4e-06,
"output_cost_per_token": 6e-06,
"output_cost_per_token_above_200k_tokens": 1.2e-05,
"cache_read_input_token_cost": 5e-07,
"cache_read_input_token_cost_above_200k_tokens": 1e-06
```

换算规则：

- 阈值取自字段名（`200k` → 200000），有多个阈值时取最小的一个。
- 倍率 = 高档价 ÷ 基础价，只看 `input_` 和 `output_` 两个字段。
- 缓存的高档价（`cache_*_above_*`）和带服务档后缀的高档价（`*_above_272k_tokens_priority`）不参与换算。实际计费时，缓存按"基础价 × 输入倍率"、priority 按"priority 基础价 × 倍率"计算。因此缓存高档价应当正好等于"缓存基础价 × 输入倍率"，否则以换算结果为准。
- 高档价不高于基础价时视为没有附加费，不生成阶梯。

两种写法同时出现时，以写法一为准。想关闭某个模型的阶梯，可以显式写 `"long_context_input_token_threshold": 0`。

### 图片

| 字段 | 含义 |
| --- | --- |
| `output_cost_per_image` | 每张输出图片的价格（按次） |
| `output_cost_per_image_token` | 输出图片 token |
| `input_cost_per_image_token` | 输入图片 token |
| `cache_read_input_image_token_cost` | 缓存命中的输入图片 token |

### 保留但 sub2api 目前不读取的价格字段

这些是 LiteLLM 原始数据里的价格信息，保留下来作参考，对计费没有影响：

| 字段 | 含义 |
| --- | --- |
| `search_context_cost_per_query` | 联网搜索的每次价格，按 `search_context_size_low/medium/high` 区分 |
| `regional_processing_uplift_multiplier_eu/us` | 区域处理加价倍率 |
| `provider_specific_entry` | 提供商特定倍率，如 `fast`（快速模式，相对标准价）、`us`（美区数据驻留） |

注意：Anthropic 的 fast mode 在 sub2api 中按 `_priority` 字段计费，`provider_specific_entry.fast` 只是参考。支持 fast mode 的模型要同时写上 `*_priority` 价格。

### 不要放进来的字段

模型能力和元数据与价格无关，不放进本目录：`max_tokens`、`max_input_tokens`、`max_output_tokens`、`supports_*`、`source`、`deprecation_date`、`tool_use_system_prompt_tokens` 等。

## 价格来源

当前数据按以下官方页面核对（2026-10-09）。约定：

- 有人民币官方价的提供商（DeepSeek、智谱、Moonshot）以国内站人民币价为准，按 **1 美元 = 7 元** 换算成美元写入。
- 只有美元价的提供商（Anthropic、OpenAI、xAI）直接使用官方美元价。
- 有峰谷价的统一使用**高峰期价格**。
- 已退役的模型不收录。

| 提供商 | 来源 | 备注 |
| --- | --- | --- |
| Anthropic | https://platform.claude.com/docs/en/about-claude/pricing | Fable 5.1 缓存读取为 0.025×，Opus 5.5 / Sonnet 5.5 为 0.05×，其余 0.1× |
| OpenAI | https://developers.openai.com/api/docs/pricing | Priority 已更名 Fast；GPT-5.6 Sol 为促销价，至少持续到 2026-11-21 |
| xAI | https://docs.x.ai/developers/pricing | ≥200k 输入进高档 |
| DeepSeek | https://api-docs.deepseek.com/zh-cn/quick_start/pricing | 高峰价（北京时间工作日 9:00–12:00、14:00–18:00）。flash ¥2 / ¥0.04 / ¥8，v4-pro ¥9 / ¥0.30 / ¥27 |
| 智谱 | https://docs.bigmodel.cn/cn/guide/start/pricing | 国内站人民币价。GLM-4.6 国内站未列按量价格，暂沿用原值 |
| Moonshot | https://platform.kimi.com/docs/pricing/chat | kimi-k3 ¥20 / 缓存命中 ¥2 / ¥100，缓存写入 5min ¥20、1h ¥40 |

### 智谱分段价的表达

智谱部分模型按输入长度分段，用"阈值 + 倍率"表达（阈值 32000）：

| 模型 | 输入 <32K（输入 / 缓存命中 / 输出） | 输入 ≥32K | 倍率（输入 / 输出） |
| --- | --- | --- | --- |
| glm-5.1 | ¥6 / ¥1.3 / ¥24 | ¥8 / ¥2 / ¥28 | 1.333 / 1.167 |
| glm-5 | ¥4 / ¥1 / ¥18 | ¥6 / ¥1.5 / ¥22 | 1.5 / 1.222 |
| glm-4.7 | ¥3 / ¥0.6 / ¥14 | ¥4 / ¥0.8 / ¥16 | 1.333 / 1.143 |
| glm-4.5-air | ¥0.8 / ¥0.16 / ¥6 | ¥1.2 / ¥0.24 / ¥8 | 1.5 / 1.333 |

两个已知偏差：

- glm-4.7、glm-4.5-air 在"输入 <32K 且输出 <0.2K"时还有更便宜的一档（¥2 / ¥0.4 / ¥8、¥0.8 / ¥0.16 / ¥2），按输出长度分档无法表达，目录统一写输出 ≥0.2K 档。
- sub2api 高档缓存价 = 缓存基础价 × 输入倍率。glm-5.1 高档缓存实际 ¥2，按倍率算是 ¥1.73，少收约 13%；其余模型一致。

## 完整示例

```json
{
  "claude-opus-5": {
    "litellm_provider": "anthropic",
    "mode": "chat",
    "input_cost_per_token": 5e-06,
    "output_cost_per_token": 2.5e-05,
    "cache_read_input_token_cost": 5e-07,
    "cache_creation_input_token_cost": 6.25e-06,
    "cache_creation_input_token_cost_above_1hr": 1e-05
  },
  "gpt-6-sol": {
    "litellm_provider": "openai",
    "mode": "chat",
    "input_cost_per_token": 2e-06,
    "input_cost_per_token_priority": 4e-06,
    "output_cost_per_token": 1e-05,
    "output_cost_per_token_priority": 2e-05,
    "cache_read_input_token_cost": 2e-07,
    "cache_read_input_token_cost_priority": 4e-07,
    "long_context_input_token_threshold": 272000,
    "long_context_input_cost_multiplier": 2.0,
    "long_context_output_cost_multiplier": 1.5
  }
}
```
