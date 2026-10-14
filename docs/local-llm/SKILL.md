---
name: local-llm
description: Operate this Mac's Home Manager local MLX models with Hermes, including choosing roles, starting and switching servers, verifying downloads, and explicit runtime updates.
---

# Use the local models

This is the operating guide for the setup in `~/.config/home-manager`.
An agent can use it when asked to operate this stack; it is repository documentation,
not automatically installed into Codex or Hermes's skill directories.
Read `config/local-llm/settings.sh` and `scripts/local-llm` in that repository for
current settings before changing anything. Do not reinstall or download models
merely to start a session.

## Choose a role

| Role | Use it for | Model | Download size, not RAM |
|---|---|---|---:|
| `coder` | Default: repository work, code explanations, coding agents | Qwen3-Coder-30B-A3B-Instruct-4bit | 16.02 GiB |
| `general` | General questions/reasoning; smaller model-weight footprint | gpt-oss-20b-OptiQ-4bit | 10.85 GiB |
| `large` | On-demand general reasoning and image requests | Qwen3.5-35B-A3B-4bit | 19.02 GiB |

All three are `mlx-community` repositories. These are intended roles, not proof
that one always answers better or faster. Only one large model should run at a time.
`general` needs the included Harmony compatibility adapter. `large` passed a basic
image test but showed thinking-like text in one answer; sustained agent reliability
is unverified. Start with `coder` for Hermes coding work.

Ollama remains separate: `nomic-embed-text:latest` supplies embeddings for indexing;
`nimble:latest` was retained outside migration scope. Embeddings are not chat models.
Do not remove these or automatically run Nimble alongside MLX.

## Start a normal session

Run `local-llm` with no arguments to open the arrow-key model picker. Select a
cached role with ↑/↓ and Enter. Selecting the currently served role aligns Hermes
and opens chat; choosing another role stops the current server only when its
process matches this Home Manager MLX runtime, then configures Hermes and starts
the selected server. Esc cancels. If another server owns port 8000, the picker
leaves Hermes unchanged and asks you to stop it manually.
The picker needs `fzf`; Home Manager installs it, and
`config/local-llm/Brewfile` includes it for direct checkout use.

```bash
local-llm status
local-llm models # alias: local-llm list
```

The model listing combines MLX roles and Ollama models in one inventory, shows
cached MLX disk size, Ollama-reported size, readiness, active serving model, and
Hermes selection. It is read-only. The interactive picker handles model startup
and role switching:

```bash
local-llm
```

The picker opens Hermes chat directly when the selected model is already serving.
When it starts a different model, leave that terminal open and use Hermes from a
second terminal:

```bash
cd /path/to/your/project
hermes chat
```

`configure-hermes` is needed on first setup or a role change, not every chat. It
backs up `~/.hermes/config.yaml` and selects that role; it does not start a server.
Changing the server alone does not update Hermes's configured model.

For a single request:

```bash
hermes chat --query 'Explain the code in this project before suggesting changes.'
```

Example of a bounded actual tool-use task (a proposed check, not a previously passed test):

```bash
cd ~/.config/home-manager
hermes chat --cli --toolsets terminal --max-turns 4 --query \
  'Use a terminal tool to read config/local-llm/settings.sh. Do not modify files. Return JSON with CODER_MODEL, GENERAL_MODEL, LARGE_MODEL and LLM_PORT from that file.'
```

Verify that a tool actually ran and that the returned values match the file. A
correct-looking answer alone does not prove tool execution. These are real tools
with access to the workstation; keep normal approval behavior enabled.

## Stop or switch models

For manual role selection, press Ctrl-C in the serving terminal, then:

```bash
local-llm configure-hermes general
local-llm serve general
# In another terminal: hermes chat
```

Substitute `large` or `coder` for both commands. Start a fresh Hermes conversation
after switching roles. The `local-llm` arrow picker automates this transition for
servers it identifies as this MLX runtime. For other servers it leaves Hermes
unchanged and asks you to stop that server manually.

The migration left a detached coder server. If there is no serving terminal:

```bash
lsof -nP -iTCP:8000 -sTCP:LISTEN
cat ~/.local/state/local-llm/coder-process.json
ps -p <PID_FROM_LSOF> -o pid=,command=
kill -TERM <VERIFIED_MLX_SERVER_PID>
```

Replace the placeholders only after confirming the listener is the intended MLX
server. The receipt can be stale; never kill a stored PID without checking identity.
Confirm the port is free before starting the replacement. The picker stops only a
server whose process command matches this venv, selected model, loopback host, and
port; it leaves other server processes running.

## Images, other clients, and concurrent work

With `large` serving and Hermes configured for `large`:

```bash
hermes chat --image /absolute/path/to/image.png --query 'Describe this image.'
```

The underlying server image path was smoke-tested; Hermes image orchestration was
not separately validated.

For another OpenAI-compatible client, use:

| Setting | Value |
|---|---|
| Base URL | `http://127.0.0.1:8000/v1` |
| API key | `not-needed` |
| Model | Exact ID shown by `local-llm models` for the active role |

The placeholder key is not authentication. The launcher binds loopback only.

For concurrent requests, first stop the current server, then explicitly use:

```bash
local-llm serve coder --continuous-batching
```

Configured maximum: two sequences. Concurrent load/performance remains unverified.
The separate `mlx-codex` workflow also defaults to port 8000 and has a different
environment/model selection. Do not start it alongside `local-llm`. The local-llm
port check prevents an occupied-port launch, not arbitrary GPU use on another port.

## Downloads, setup, and updates

Weights persist in the Hugging Face cache (normally `~/.cache/huggingface/hub`;
`HF_HOME` can relocate it). Serving is offline and does not download missing files.
Runtime packages live in `~/.venvs/vllm-mlx`; the old `~/vllm-mlx` checkout is not
required by this workflow.

Only when installing or intentionally refreshing:

```bash
local-llm setup mlx          # install/update runtime, not weights
local-llm setup ollama       # adopt/update Homebrew Ollama app
local-llm download coder     # fetch/complete this model
local-llm download general
local-llm download large
```

`download all` includes all three MLX roles AND the Ollama embedding model; do not
run it as a routine health check. No weights are automatically removed.

With the server stopped, explicit updates:

```bash
local-llm update mlx
local-llm update ollama
```

These follow current upstream versions by user choice. Runtime update does not
refresh weights; `download ROLE` is separate. Home Manager activation installs
wrappers/config references but does not update runtimes, fetch weights, change
Hermes, or start a model. Source changes to scripts/settings need activation to
reach the installed wrapper; `./scripts/local-llm` uses the checkout directly.

After MLX updates:

```bash
cd ~/.config/home-manager
PYTHONDONTWRITEBYTECODE=1 ~/.venvs/vllm-mlx/bin/python -m unittest discover \
  -s tests -p 'test_local_llm_gpt_oss_compat.py'
```

Then validate basic generation and actual tool-call/result exchanges, including
streaming, before trusting the general role. Tests need Metal access; a sandbox
without GPU access can fail importing MLX. The adapter performs startup checks but
cannot guarantee compatibility with every future unpinned upstream version.

To verify a downloaded revision without redownloading:

```bash
~/.venvs/vllm-mlx/bin/hf cache verify \
  mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit \
  --revision <CACHED_COMMIT> --fail-on-missing-files
```

Repeat for the other IDs. Use the cached commit, not a newer remote `main`, to
distinguish corruption/incompleteness from a later upstream revision. This contacts
Hugging Face for metadata and hashes local files. The strict flag can also report
missing README/license/repository metadata intentionally excluded by the model
downloader; distinguish those from missing weights, tokenizers, or configs. A local
`vllm_mlx_model_manifest.json` is generated metadata, not a remote model file.
See [download-verification.json](download-verification.json) for checked revisions,
exact missing/extra paths, and checksum results.

## Memory and troubleshooting

| Symptom | Action |
|---|---|
| Port 8000 occupied | Inspect listener and `/v1/models`; reuse correct server or stop the verified one. Do not launch a second model blindly. |
| Offline cache/model missing | Run `download ROLE` explicitly, then checksum verification. Check `HF_HOME` matches the serving environment. |
| Hermes model mismatch | Check active `/v1/models`; run `configure-hermes` for that same role. |
| Slow Mac / increasing swap | Inspect Activity Monitor memory pressure, `vm_stat`, `sysctl vm.swapusage`, and `df -h /`. Stop the model if disruptive; use shorter conversations or the smaller general role. |
| GPT-OSS parser/startup error after update | Preserve error output; rerun adapter tests and inspect upstream compatibility. Do not silently disable reasoning parsing: that previously leaked protocol/reasoning text. |

Configured Hermes context is 65,536 because the installed client required at least
64,000. It is not a promise that a full-length conversation fits comfortably. Output
limit is 4,096 and prefix-cache budget 1 GiB; neither is a total RAM limit. Substantial
swap was observed during migration. `large` is an on-demand option; account for
other applications and disk headroom before starting it.

Basic API generation/tool and one Hermes plain-answer smoke passed during migration.
Sustained coding, full-context memory, Hermes tool orchestration, and concurrent
throughput are not yet qualified for daily-driver reliability.

`local-llm cleanup-ollama` previews the original six retirement targets;
`--apply` deletes them. Migration already retired them. Cleanup is not needed for
daily use and is not permission to remove other models.
