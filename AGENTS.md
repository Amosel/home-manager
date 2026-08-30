# Repo Guidance

This repository is a Home Manager setup for macOS on Apple Silicon.

Prefer `home.nix`, `flake.nix`, and `flake.lock` as the source of truth over the README.

When reviewing or changing this repo:

- Treat it as `codex`-first, not Claude-first.
- Favor small, reversible Home Manager changes over broad tool additions.
- Flag doc drift whenever the README claims behavior or files that are not present.
- Flag non-reproducible inputs such as unpinned GitHub `HEAD` fetches.
- Distinguish between global workstation tooling and project-local tooling.
- Prefer adding reusable skills or scripts before adding more shell aliases.

Before proposing new agent tooling, check:

- whether it improves local Codex workflows directly
- whether it can run headless and declaratively
- whether it adds maintenance burden or auth complexity
