# shellcheck shell=bash disable=SC2034
# Shell manifest, sourced by scripts/local-llm. No credentials here.
# Reuse the existing partial installation; setup replaces its editable package.
LLM_VENV="${LLM_VENV:-$HOME/.venvs/vllm-mlx}"
LLM_PYTHON="${LLM_PYTHON:-3.12}"
LLM_PORT=8000
# Hermes enforces a minimum 64,000-token context window.
LLM_CONTEXT=65536
LLM_OUTPUT=4096
LLM_CACHE_MB=1024
LLM_BATCH_SEQUENCES=2

CODER_MODEL=mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit
GENERAL_MODEL=mlx-community/gpt-oss-20b-OptiQ-4bit
LARGE_MODEL=mlx-community/Qwen3.5-35B-A3B-4bit
EMBED_MODEL=nomic-embed-text:latest
