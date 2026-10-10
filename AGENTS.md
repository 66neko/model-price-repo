# AI Agent 维护指南

本文档规定 AI agent 在本仓库中的权限范围和操作规范。

## 项目简介

本仓库维护 sub2api 的远程模型定价目录（LiteLLM 格式），核心文件为 `model_prices_and_context_window.json`，包含各大 AI 模型提供商的价格信息。

## AI 权限和限制

### 允许的日常操作

AI agent **仅允许**对以下文件进行修改：

1. **`model_prices_and_context_window.json`**
   - 添加新模型的价格条目
   - 更新现有模型的价格
   - 修正价格数据错误
   - 删除已废弃的模型

2. **`model_prices_and_context_window.sha256`**
   - 在修改 JSON 后自动更新哈希值（通过 `scripts/update-hash.sh`）

### 禁止的操作

除非用户**明确指定**要修改，否则 AI agent **不得**修改以下内容：

- `README.md`：项目文档和说明
- `.github/` 目录：CI/CD 配置和 GitHub Actions
- `scripts/` 目录：维护脚本
- 其他任何配置文件或文档

**重要**：文档维护属于独立任务，需要用户明确授权后才能执行。

## 价格维护流程

### 1. 添加新模型

新模型必须插入到 JSON 文件的**头部**（最新模型在最前）：

```json
{
  "new-model-name": {
    "litellm_provider": "anthropic",
    "mode": "chat",
    "input_cost_per_token": 2e-06,
    "output_cost_per_token": 1e-05,
    "cache_read_input_token_cost": 2e-07
  },
  "existing-model": { ... }
}
```

### 2. 更新现有模型价格

直接修改对应模型的价格字段：

- 所有价格单位为**美元/token**
- 使用科学计数法：`$3/百万token` = `3e-06`
- 价格来源必须基于官方定价页面

### 3. 更新哈希

修改 JSON 后必须更新 sha256：

```bash
bash scripts/update-hash.sh
```

GitHub Action 会在推送到 main 后自动执行，本地开发时也应主动运行。

## 价格数据规范

### 必需字段

条目至少要有以下之一，否则会被忽略：
- `input_cost_per_token`
- `output_cost_per_token`
- 任一图片价格字段

### 常用字段

| 字段 | 说明 |
|------|------|
| `litellm_provider` | 提供商：`anthropic`/`openai`/`xai`/`deepseek` 等 |
| `mode` | `chat` 或 `image_generation` |
| `input_cost_per_token` | 输入 token 价格 |
| `output_cost_per_token` | 输出 token 价格 |
| `cache_read_input_token_cost` | 缓存读取价格 |
| `cache_creation_input_token_cost` | 缓存写入价格（5分钟） |

### 价格来源

更新价格时必须参考官方定价页面：

- **Anthropic**: https://platform.claude.com/docs/en/about-claude/pricing
- **OpenAI**: https://developers.openai.com/api/docs/pricing
- **xAI**: https://docs.x.ai/developers/pricing
- **DeepSeek**: https://api-docs.deepseek.com/zh-cn/quick_start/pricing（使用高峰价，¥7 = $1）
- **智谱**: https://docs.bigmodel.cn/cn/guide/start/pricing（人民币价，¥7 = $1）
- **Moonshot**: https://platform.kimi.com/docs/pricing/chat（人民币价，¥7 = $1）

### 定价规则

1. **峰谷价**：使用高峰期价格
2. **人民币换算**：1 美元 = 7 元人民币
3. **模型名**：使用小写
4. **排序**：新模型在前，旧模型在后

## 验证清单

在提交价格更新前，AI agent 应确认：

- [ ] 价格来源于官方定价页面
- [ ] 新模型插入在 JSON 文件头部
- [ ] 使用科学计数法（如 `3e-06`）
- [ ] 模型名为小写
- [ ] 必需字段完整
- [ ] 已运行 `scripts/update-hash.sh` 更新哈希
- [ ] JSON 格式正确（无语法错误）

## 特殊操作授权

以下操作需要用户明确授权：

### 需要明确指令的操作

- 修改 README.md 或其他文档
- 修改 CI/CD 配置
- 修改维护脚本
- 删除大量模型条目
- 更改 JSON 文件结构

### 授权示例

✅ **允许**："请添加 claude-opus-5-5 的价格"
✅ **允许**："更新 gpt-6-sol 的输入价格为 $2/百万 token"
❌ **不允许**：自行修改 README 添加新模型说明
✅ **需明确授权**："请同时更新价格和 README 文档"

## 错误处理

遇到以下情况应停止操作并询问用户：

1. 价格信息不完整或来源不明
2. 需要修改文档或配置文件
3. 模型名或提供商标识不确定
4. JSON 结构需要重大调整
5. 删除多个模型条目

## 提交规范

价格更新的 commit message 格式：

```
feat: add <model-name> pricing
feat: update <model-name> pricing
fix: correct <model-name> input cost
chore: remove deprecated models
```

## 参考信息

- 详细的字段说明和格式规范见 `README.md`
- 价格更新后，jsDelivr 镜像最长需要 12 小时生效
- raw.githubusercontent.com 直连无缓存延迟
