# macOS Home Manager Dev Environment

Codex-first workstation configuration for macOS on Apple Silicon (`aarch64-darwin`). The single root profile is `amoselmaliah`, with home directory `/Users/amoselmaliah`.

[home.nix](home.nix), [flake.nix](flake.nix), [flake.lock](flake.lock), and the imported modules are the source of truth. This repo manages global workstation tooling; project dependencies belong in project environments. Keep credentials outside the repo and Nix expressions.

## Repository layout

| File | Responsibility |
| --- | --- |
| `home.nix` | Module composition, username, home directory, Home Manager state version |
| `flake.nix` / `flake.lock` | Apple Silicon profile and locked Nixpkgs, Home Manager, Hermes inputs |
| `modules/packages.nix` | CLI packages, pinned Codex/search/xurl releases, `scan-secrets` |
| `modules/shell.nix` | Zsh/Bash, PATH, aliases, terminal tools, environment variables |
| `modules/git.nix` | Git identity, Delta, Kaleidoscope commands, GitHub CLI |
| `modules/editor.nix` | Neovim plugins, LSP, completion, formatting, linting |
| `modules/ai.nix` | Whisper, skill wiring, MLX helper, OpenClaw activation |
| `codex-skills/home-manager-review/` | Bundled Codex review skill |
| `Brewfile` | Separate Homebrew bundle, including casks, services, Go and Cargo entries |
| `bootstrap.sh` | Machine bootstrap and activation |
| `scripts/verify.sh` | Installed-environment smoke checks |

`nvim/default.nix` is a legacy stub. `vm/flake.nix` declares an `x86_64-linux` profile but imports the macOS-specific `home.nix`; it is not a ready-to-use Linux configuration.

## Included tooling

- **Shell:** Zsh completion, autosuggestions and syntax highlighting; Bash; Starship, fzf, zoxide, direnv/nix-direnv, Atuin, tmux, `lla`, and `eza`. Atuin automatic sync and update checks are disabled. Tmux prefix: `Ctrl-a`.
- **Development:** Git, `gh`, `glab`, `uv`, `pipx`, Node.js/fnm, Docker CLI, Kubernetes tools, Ansible, language servers, formatters, and linters. Installing a CLI does not provision its daemon, cluster, or credentials.
- **Editor:** Neovim with Nix-managed plugins, Treesitter, Telescope, Neo-tree, Gitsigns, completion, LSP, format-on-save, and linting. Active configuration: `modules/editor.nix`.
- **Media/documents:** FFmpeg, yt-dlp, whisper.cpp, Poppler, OCRmyPDF, Pandoc, Tika (`tika-app`), and ExifTool.
- **Security:** Trivy, Gitleaks, SOPS, ShellCheck, Hadolint, Statix, and Deadnix.
- **Agents/search:** Codex CLI, Hermes, `search`, `xurl`, a bundled Codex review skill, and helpers described below. Authentication remains separate.

Useful shell shortcuts: `hms` applies this profile; `c` launches Codex; `v` launches Neovim. Bare `ls` uses `lla`; `ls` with arguments uses `/bin/ls`. `lraw` always uses `/bin/ls`.

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

`./scripts/verify.sh` checks command availability, repository paths, skill variables, the managed Codex binary and PATH selection, and headless Neovim startup. Optional tools produce warnings; required failures produce a nonzero exit. It does not verify service health, authentication, transcription accuracy, or every installed tool.

## Codex and local helpers

Codex CLI **0.157.0** is installed from the hash-pinned complete upstream Apple Silicon package, including its companion resources. Update the version and release hash together in `modules/packages.nix`; the Nixpkgs pin is independent. After switching, start a fresh shell. Verification rejects a selected Codex binary that differs from `~/.nix-profile/bin/codex`.

Home Manager installs the bundled `home-manager-review` skill into `~/.codex/skills`. `skill-audit [--format text|json]` depends on external local sources:

- `/Users/amoselmaliah/dev/scripts/skills` (including the skill-manager Python script)
- `/Users/amoselmaliah/dev/scripts/persona/personas/matt-pocock/skills`

Those libraries are not included or installed by this repo. The `chatgpt-export-workspaces` wrapper is added only when its external script exists at evaluation time.

`mlx-codex` provides `run`, `serve`, `stop`, and `logs` commands. It expects an existing `~/.venv-vllm-metal/bin/vllm-mlx`; this repo does not create that environment. The helper defaults to `mlx-community/gemma-4-31b-it-4bit` and loopback port 8000. Overrides: `MLX_PORT`, `MLX_MAX_TOKENS`.

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
- External skill libraries, the optional export script, local MLX environment/models, and independently installed SDKs are not reproduced by the Nix lock file.
