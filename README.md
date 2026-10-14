# macOS Home Manager Dev Environment

Workstation configuration for macOS on Apple Silicon (`aarch64-darwin`). The macOS profile is `amoselmaliah`, with home directory `/Users/amoselmaliah`. Development continues on `main`; the separate Ubuntu Droplet profile is retained for reference.

[home.nix](home.nix), [flake.nix](flake.nix), [flake.lock](flake.lock), and the imported modules are the source of truth. This repo manages global workstation tooling; project dependencies belong in project environments. Keep credentials outside the repo and Nix expressions.

## Repository layout

| File | Responsibility |
| --- | --- |
| `home.nix` | Module composition, username, home directory, Home Manager state version |
| `flake.nix` / `flake.lock` | Apple Silicon profile and locked Nixpkgs, Home Manager, Hermes inputs |
| `droplet/flake.nix` / `droplet/flake.lock` | Separately locked Linux profile inputs |
| `droplet/home.nix` | Linux CLI, Bash, Git, and editor profile for the Droplet's root/admin and codex accounts |
| `modules/packages.nix` | CLI packages, pinned search/xurl releases, `scan-secrets` |
| `modules/shell.nix` | Zsh/Bash, PATH, aliases, terminal tools, environment variables |
| `modules/git.nix` | Git identity, Delta, Kaleidoscope commands, GitHub CLI |
| `modules/editor.nix` | Neovim plugins, LSP, completion, formatting, linting |
| `modules/ai.nix` | Whisper, OpenClaw activation, and the `local-llm` command |
| `config/local-llm/` / `scripts/local-llm` | Unpinned, explicitly executed Ollama/MLX setup and model roles |
| `Brewfile` | macOS Homebrew bundle; Linux-compatible CLI equivalents are mapped into `droplet/home.nix` |
| `bootstrap.sh` | Machine bootstrap and activation |
| `scripts/verify.sh` | Installed-environment smoke checks |

`nvim/default.nix` is a legacy stub. `vm/flake.nix` declares an `x86_64-linux` profile but imports the macOS-specific `home.nix`; it is not a ready-to-use Linux configuration.

Droplet development ended on 2026-10-11. Its profile remains a separate flake and deliberately avoids importing macOS-specific modules. The application command below is retained for reference and applies only to the Droplet:

```bash
home-manager switch -b hm-backup --flake ~/.config/home-manager/droplet#codex@codex-vast-flint-fae5
```

The profiles target `codex` at `/home/codex` and `root` at `/root`; account creation and sudo privileges are managed separately. The `hm-backup` suffix preserves existing dotfiles that collide with managed files, provided the backup destination does not already exist.

The Droplet profile converts Brewfile CLI tools to Nix packages where available; `mactex-no-gui` maps to `texliveSmall`. Homebrew taps and GUI apps remain macOS-only. Other exclusions: `cocoapods` and `cargo-lipo` are Darwin-specific; `ruby-build`, `container-use`, `diskdiet-mcp`, and several Cargo entries have no package in the locked Nixpkgs (`beaker`, `cargo-run-script`, `cbindgen`, `cosmwasm-check`, `genson-rs`, `imessage-exporter`, `ralph-cli`, `uniffi_bindgen`). Cargo supplies `cargo tree` directly. PostgreSQL is installed as software only; Home Manager does not enable its system service. `1password-cli`, `ngrok`, and `trunk-io` are the only allowed unfree packages.

## Included tooling

- **Shell:** Zsh completion, autosuggestions and syntax highlighting; Bash; Starship, fzf, zoxide, direnv/nix-direnv, Atuin, tmux, `lla`, and `eza`. Atuin automatic sync and update checks are disabled. Tmux prefix: `Ctrl-a`.
- **Development:** Git, `gh`, `glab`, `uv`, `pipx`, Node.js/fnm, Docker CLI, Kubernetes tools, Ansible, language servers, formatters, and linters. Installing a CLI does not provision its daemon, cluster, or credentials.
- **Editor:** Neovim with Nix-managed plugins, Treesitter, Telescope, Neo-tree, Gitsigns, completion, LSP, format-on-save, and linting. Active configuration: `modules/editor.nix`.
- **Media/documents:** FFmpeg, yt-dlp, whisper.cpp, Poppler, OCRmyPDF, Pandoc, Tika (`tika-app`), and ExifTool.
- **Security:** Trivy, Gitleaks, SOPS, ShellCheck, Hadolint, Statix, and Deadnix.
- **Agents/search:** Hermes, `search`, `xurl`, and helpers described below. Authentication remains separate.

Useful shell shortcuts: `hms` applies this profile; `v` launches Neovim. Bare `ls` uses `lla`; `ls` with arguments uses `/bin/ls`. `lraw` always uses `/bin/ls`.

## Setup

This configuration contains personal paths and Git identity. For another user, first adapt `home.nix`, the profile in `flake.nix`, and hard-coded paths/identity in the modules. PATH entries for Android Studio, Flutter, Daml, and other SDKs do not install those SDKs. Git's configured `ksdiff` tool requires a separate Kaleidoscope installation.

Install Xcode Command Line Tools and Nix first. Finish the macOS installer prompt before continuing:

```bash
xcode-select --install
curl -L https://nixos.org/nix/install | sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

Enable `nix-command flakes` in `~/.config/nix/nix.conf` (merge with existing settings):

```ini
experimental-features = nix-command flakes
```

Clone this repo into `~/.config/home-manager`, then build and activate using the committed lock file:

```bash
cd ~/.config/home-manager
nix build .#homeConfigurations.amoselmaliah.activationPackage
./result/activate
```

Start a fresh shell, then run:

```bash
~/.config/home-manager/scripts/verify.sh
```

For the broader bootstrap, run `./bootstrap.sh` from an existing checkout. It installs missing Xcode tools, Nix, and Homebrew; enables flakes; runs `brew bundle --no-lock`; activates Home Manager; and attempts verification. `DOTFILES_REPO_URL` optionally supplies a clone URL and triggers `git pull` when the target checkout already exists. Review these side effects before running it.

## Apply and update

Apply configuration changes without updating dependencies:

```bash
cd ~/.config/home-manager
nix build .#homeConfigurations.amoselmaliah.activationPackage
home-manager switch --flake .#amoselmaliah
./scripts/verify.sh
```

To update flake inputs, run `nix flake update`, review `git diff -- flake.lock`, then build and apply as above. This updates all inputs; it does not update separately versioned release derivations or Homebrew packages.

If activation reports an existing-file conflict, inspect that file first. `home-manager switch -b hm-backup --flake .#amoselmaliah` can preserve conflicting files under a backup suffix. Sourcing `.zshrc` alone does not apply Nix changes.

`./scripts/verify.sh` checks command availability, repository paths, and headless Neovim startup. Optional tools produce warnings; required failures produce a nonzero exit. It does not verify service health, authentication, transcription accuracy, or every installed tool.

Install Codex independently using its [official installer](https://chatgpt.com/codex/install.sh):

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

The `chatgpt-export-workspaces` wrapper is added only when its external script exists at evaluation time.

## Local models: explicit setup and updates

For model selection, daily use, switching, Hermes commands, and troubleshooting,
read the [local-model operating skill](docs/local-llm/SKILL.md).

`scripts/local-llm` works directly from this checkout. Home Manager also installs
`local-llm` on PATH after activation. Settings and model IDs live in
[`config/local-llm/settings.sh`](config/local-llm/settings.sh); its sibling
`requirements.txt` follows the vLLM-MLX default Git branch, and its `Brewfile`
installs the arrow-key picker (`fzf`) and manages the Ollama macOS app. Home
Manager already provides `fzf`; Brewfile also covers direct checkout use.
Neither runtime is pinned by Nix. These are
deliberately non-reproducible updates, performed only when requested:

```bash
cd ~/.config/home-manager
local-llm                               # ↑/↓ choose a model; Enter starts it
local-llm models                       # MLX + Ollama inventory, sizes, use
./scripts/local-llm setup               # runtimes only; no weights or servers
./scripts/local-llm download coder      # explicit large download
./scripts/local-llm configure-hermes coder
./scripts/local-llm serve coder         # foreground; Ctrl-C to stop

# Later, with the server stopped:
./scripts/local-llm update              # latest upstream code/dependencies and Ollama
./scripts/local-llm download general
./scripts/local-llm configure-hermes general
./scripts/local-llm serve general
```

`setup mlx` / `update mlx` and `setup ollama` / `update ollama` operate independently.
MLX reuses `~/.venvs/vllm-mlx` and replaces the editable install with a normal Git
package installation. After successful setup, `~/vllm-mlx` is no longer a runtime
dependency; the checkout is left intact. Python 3.12 is the default for new
environments, configurable via `LLM_PYTHON`; existing environments are retained.
Ollama setup attempts Homebrew's safe `--adopt` for an existing app. If the app
differs from the current cask, adoption may fail; update it through Ollama and
retry. No forced replacement or model deletion is performed.

Models reuse the normal Hugging Face cache (`HF_HOME` is respected). `download`
defaults to the coder alone; `download large`, `download embeddings`, and
`download all` are opt-in. Embedding downloads require Ollama running. Existing
Ollama models, including `nomic-embed-text:latest`, are untouched by setup/download. Downloaded
weights occupy disk; loaded models consume memory. Stop any loaded large Ollama
models before using MLX (`ollama ps`, then `ollama stop <model>`).

Serving binds only `127.0.0.1:8000`, uses cached weights offline, enables the
role's tool parser, and prevents idle system sleep while running. A port check
rejects an already-running listener before loading weights; it is not a global
GPU lock and cannot stop independently launched servers. The default is one
sequence, 4,096 output tokens, and a 1 GiB prefix-cache budget. These are **not a
total RAM cap**. `configure-hermes` backs up its config and sets the custom
provider, endpoint, placeholder key, model, 65,536-token context, and output
limit; other settings survive. The installed Hermes rejects contexts below
64,000 tokens. This context is a Hermes setting, not a server-side input limit;
longer conversations can increase memory use. Existing auxiliary providers,
fallbacks, and compression settings remain configured separately.
`serve coder --continuous-batching` opts into the batched engine with at most two
sequences (`LLM_BATCH_SEQUENCES` in the manifest).

Roles: `coder` = `mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit`,
`general` = `mlx-community/gpt-oss-20b-OptiQ-4bit`, and
`large` = `mlx-community/Qwen3.5-35B-A3B-4bit`.
Test each replacement before retiring its Ollama copy.

The general role runs `scripts/local-llm-gpt-oss-compat.py`: a process-local
compatibility adapter for upstream Harmony cleanup/streaming bugs. It preserves
tool-call headers until parsing and separates reasoning from answer content.
It probes upstream behavior at startup, skips working portions, and fails on
unsupported parser contracts; installed package files are never modified.
Coder/large roles do not load it. After runtime updates, rerun the focused tests
with `~/.venvs/vllm-mlx/bin/python -m unittest discover -s tests -p
"test_local_llm_gpt_oss_compat.py"` plus live generation/tool roundtrips.

`local-llm cleanup-ollama` previews the six exact retirement names;
`local-llm cleanup-ollama --apply` deletes them. Absent names are skipped;
failures stop execution. Both preserve `nomic-embed-text:latest`, `nimble:latest`,
and every unlisted model. No automatic startup/restart service is installed.

The separate `mlx-codex` workflow retains its own `~/.venv-vllm-mlx` environment,
model defaults, and continuous-batching behavior. Its `setup` resolves the same
unpinned upstream source. Stop either workflow before starting the other on port
8000; run only one large model at a time.

`local-llm status` reports installation provenance and API availability. No
generation or multi-turn tool-calling benchmark is implied. Upstream references:
[MLX installation](https://vllm-mlx.is-a.dev/getting-started/installation/),
[MLX serving](https://vllm-mlx.is-a.dev/getting-started/quickstart/), and
[Hermes configuration](https://hermes-agent.nousresearch.com/docs/user-guide/configuration).

`home-manager switch` installs the wrapper only: it does not update these
runtimes, download weights, start services, or rewrite Hermes configuration.

## Transcription and secret scans

The hash-pinned Whisper `large-v3-turbo` model is linked at `~/.local/share/whisper-models/ggml-large-v3-turbo.bin`.

```bash
# Normalize media and write .txt, .srt, and .vtt outputs
whisper-transcribe recording.m4a output/recording

# Force CPU execution when Metal is unavailable
WHISPER_NO_GPU=1 whisper-transcribe recording.m4a output/recording

# Scan with redacted Gitleaks output
scan-secrets             # working tree, excluding Git history
scan-secrets --history   # Git history
scan-secrets --env       # current environment through stdin
scan-secrets --all       # sequential scans; stops on first failure
```

Lower-level helpers: `whisper-convert <input> <output.wav>`, `whisper-fast <16kHz.wav>`, and `whisper-evidence <16kHz.wav> <output_stem>`.

## Activation and reproducibility boundaries

- OpenClaw activation merges workspace and gateway settings into `~/.openclaw/openclaw.json`. Managed values win; other existing keys survive. Gateway configuration uses loopback port 18789. This does not install or start the OpenClaw gateway.
- Activation installs an **unpinned** `clawhub` npm package into `~/.npm-global` when its executable is missing. This requires network access and falls outside `flake.lock`.
- `bootstrap.sh` uses live Nix/Homebrew installers, including Homebrew's GitHub `HEAD` script, and an unlocked Home Manager runner. The manual build above uses the repo's locked Home Manager input.
- `Brewfile` versions are not pinned and overlap some Nix tools. Homebrew bundle changes are separate from `home-manager switch`.
- The optional export script and independently installed SDKs are not reproduced by the Nix lock file.


### Global Codex hooks

Definitions: [`config/codex-hooks.toml`](config/codex-hooks.toml). Deployment authority:
`~/dev/scripts/skills/skill-manager/scripts/skill_manager.py hooks`.
Run `hooks plan`, `hooks apply --execute`, then `hooks validate`. Home Manager
provides workstation tooling; it does not write runtime `~/.codex/hooks.json`.
The manifest declares Python and Atuin by executable name;
no new package or Home Manager activation is required. See skill-manager's
`references/hooks.md` for schema, rollback, ownership and trust review.


The hook manifest is now TOML v2. Its sibling `config/hook-assets/` contains
hash-pinned deployment snapshots. It has no absolute workstation source paths;
tools resolve from PATH at apply time. Journal state defaults to
`~/.local/state/work-journal/.data/`. Old JSON manifest retired after migration.
