# DeepSeek Integration Guide

## Overview

LoopSE now supports DeepSeek API for LLM-based milestone generation. DeepSeek provides an OpenAI-compatible API with competitive pricing and performance.

## Setup

### 1. Install Dependencies

```bash
pip install openai
```

### 2. Get DeepSeek API Key

1. Visit https://platform.deepseek.com/
2. Sign up and get your API key
3. Your key will look like: `sk-...`

### 3. Set Environment Variable (Optional)

```bash
export DEEPSEEK_API_KEY="your-api-key-here"
```

## Usage

### Method 1: Using CLI Arguments

```bash
python3 -m main 5 designs/test-designs/test_2.v --sv --auto-plan \
  --llm-provider deepseek \
  --llm-api-key sk-your-key-here
```

### Method 2: Using Environment Variable

```bash
export DEEPSEEK_API_KEY="sk-your-key-here"
python3 -m main 5 designs/test-designs/test_2.v --sv --auto-plan \
  --llm-provider deepseek
```

### Method 3: Custom Base URL (for proxies or alternative endpoints)

```bash
python3 -m main 5 designs/test-designs/test_2.v --sv --auto-plan \
  --llm-provider deepseek \
  --llm-api-key sk-your-key-here \
  --llm-base-url https://api.deepseek.com
```

## Supported Providers

| Provider | CLI Flag | API Key Format | Base URL |
|----------|----------|----------------|----------|
| OpenAI | `--llm-provider openai` | `sk-...` | https://api.openai.com |
| Anthropic | `--llm-provider anthropic` | `sk-ant-...` | https://api.anthropic.com |
| DeepSeek | `--llm-provider deepseek` | `sk-...` | https://api.deepseek.com |
| Auto-detect | `--llm-provider auto` | (detects from key) | (default) |

## DeepSeek Model

The integration uses DeepSeek's `deepseek-chat` model, which is optimized for:
- Code understanding and generation
- Reasoning tasks
- Cost-effective API calls

## Example Output

```bash
$ python3 -m main 1 designs/test-designs/test_2.v --sv --auto-plan --llm-provider deepseek --llm-api-key sk-...

[main] Auto-plan enabled (provider=deepseek, mock=False)
[ExecutionEngine] Auto-plan mode enabled
[LLMPlanner] Using DeepSeek API at https://api.deepseek.com
[assertion_extractor] Found 2 assertion(s)
[ExecutionEngine] Found 2 verification target(s) from assertions
[ExecutionEngine] Planning for: Violate assertion 'out <= 2' in place_holder
[LLMPlanner] Generated 4 milestones (attempt 1)
[ExecutionEngine]   Step 1: Reset active (place_holder.RST == 1)
[ExecutionEngine]   Step 2: Counter initialized (place_holder.out == 0)
[ExecutionEngine]   Step 3: First increment (place_holder.out == 1)
[ExecutionEngine]   Step 4: Target reached (place_holder.out > 2)
```

## Testing Without API Key

Use mock mode for testing without making API calls:

```bash
python3 -m main 1 designs/test-designs/test_2.v --sv --auto-plan --mock
```

## Pricing Comparison

| Provider | Model | Input (per 1M tokens) | Output (per 1M tokens) |
|----------|-------|----------------------|------------------------|
| OpenAI | GPT-4 | $30 | $60 |
| Anthropic | Claude Sonnet 4 | $3 | $15 |
| DeepSeek | deepseek-chat | $0.14 | $0.28 |

DeepSeek offers significant cost savings for milestone generation tasks.

## Troubleshooting

### Error: "Could not import openai library"

```bash
pip install openai
```

### Error: "No API key provided"

Set the environment variable or use `--llm-api-key`:

```bash
export DEEPSEEK_API_KEY="sk-your-key-here"
```

### Error: "API error: 401 Unauthorized"

Check that your API key is valid and has not expired.

### Error: "API error: Rate limit exceeded"

DeepSeek has rate limits. Wait a moment and retry, or upgrade your plan.

## Advanced Configuration

### Custom Timeout

The OpenAI client uses default timeouts. To customize:

```python
# In frontend/llm_planner.py, modify _init_client():
self.client = OpenAI(
    api_key=api_key,
    base_url=base_url,
    timeout=60.0  # seconds
)
```

### Custom Model

To use a different DeepSeek model:

```python
# In frontend/llm_planner.py, modify _call_openai():
if self.provider == "deepseek":
    model = "deepseek-reasoner"  # or other DeepSeek models
```

## Integration Details

The DeepSeek integration reuses the OpenAI client with a custom base URL:

```python
from openai import OpenAI
client = OpenAI(
    api_key="sk-your-key",
    base_url="https://api.deepseek.com"
)
```

This works because DeepSeek implements the OpenAI-compatible API specification.
