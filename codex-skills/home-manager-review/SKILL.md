---
name: home-manager-review
description: Review this Home Manager setup for drift, outdated assumptions, reproducibility issues, and high-value modernizations.
---

# Home Manager Review

Use this skill when reviewing this repository's workstation setup, especially when the user wants practical upgrades without adding unnecessary complexity.

## Goals

- Identify the highest-value next improvement, not a broad rewrite.
- Prefer Codex-first recommendations.
- Separate immediate wins from speculative tooling.
- Keep recommendations grounded in the actual repo contents.

## Review Workflow

1. Read `flake.nix`, `home.nix`, and `flake.lock`.
2. Check for repo guidance in `AGENTS.md`.
3. Compare README claims against the real files and config.
4. Look for:
   - hardcoded PATH assumptions
   - stale bootstrap steps
   - non-reproducible fetches
   - agent wrappers that should become managed config
   - missing declarative support for favored tools
5. Recommend one change first, then optionally list the next two.

## Output Style

- Lead with findings, ordered by severity.
- Be explicit about file references.
- Prefer “do this next” over long option lists.
- If suggesting new tooling, explain why it is worth the maintenance cost.

## Current Biases For This Repo

- `codex` is the primary agent.
- Claude Code is secondary and should support, not define, the workstation.
- Playwright and MCP tools should be added only when they solve a clear problem.
- Local-model tooling should focus on background jobs, indexing, and low-cost automation.
