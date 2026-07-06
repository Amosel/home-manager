{ config, lib, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  skillSourceRepo = "/Users/amoselmaliah/dev/scripts/skills";
  personaSkillSourceRepo = "/Users/amoselmaliah/dev/scripts/persona/personas/matt-pocock/skills";
  codexSkillsDir = "${homeDir}/.codex/skills";
  skillRegistryDir = "${homeDir}/.local/state/skill-manager/registry";
  skillArchiveDir = "${homeDir}/.local/state/skill-manager/archive";
  skillManagerScript = "${skillSourceRepo}/skill-manager/scripts/skill_manager.py";

  # Declaratively managed subset of ~/.openclaw/openclaw.json.
  # Runtime-written keys (wizard, meta, gateway.auth) are preserved on merge.
  openclawConfig = builtins.toJSON {
    agents = {
      defaults = {
        workspace = "~/.openclaw/workspace";
      };
    };
    gateway = {
      mode = "local";
      port = 18789;
      bind = "loopback";
    };
  };

  openclawConfigFile = pkgs.writeText "openclaw-managed.json" openclawConfig;
in
{
  home.sessionVariables = {
    SKILL_SOURCE_REPO = skillSourceRepo;
    SKILL_PERSONA_SOURCE_REPO = personaSkillSourceRepo;
    CODEX_SKILLS_DIR = codexSkillsDir;
    SKILL_REGISTRY_DIR = skillRegistryDir;
    SKILL_ARCHIVE_DIR = skillArchiveDir;
  };

  home.file = {
    ".codex/skills/home-manager-review".source = ../codex-skills/home-manager-review;
  };

  home.packages = [
    (pkgs.writeShellScriptBin "skill-audit" ''
      set -euo pipefail

      format="text"
      if [ "$#" -ge 2 ] && [ "$1" = "--format" ]; then
        format="$2"
        shift 2
      fi
      if [ "$#" -ne 0 ]; then
        echo "usage: skill-audit [--format text|json]" >&2
        exit 2
      fi

      script="${skillManagerScript}"
      runtime_dir="${codexSkillsDir}"
      registry_dir="${skillRegistryDir}"
      archive_dir="${skillArchiveDir}"
      primary_source="${skillSourceRepo}"
      persona_source="${personaSkillSourceRepo}"

      tmpdir="$(mktemp -d)"
      cleanup() {
        rm -rf "$tmpdir"
      }
      trap cleanup EXIT

      run_bundle() {
        local label="$1"
        local source_repo="$2"

        python3 "$script" check-readiness \
          --source-repo "$source_repo" \
          --runtime-dir "$runtime_dir" \
          --registry-dir "$registry_dir" \
          --archive-dir "$archive_dir" \
          --format json >"$tmpdir/$label-readiness.json"

        python3 "$script" inventory \
          --source-repo "$source_repo" \
          --runtime-dir "$runtime_dir" \
          --format json >"$tmpdir/$label-inventory.json"

        python3 "$script" audit \
          --source-repo "$source_repo" \
          --runtime-dir "$runtime_dir" \
          --registry-dir "$registry_dir" \
          --format json >"$tmpdir/$label-audit.json"
      }

      run_bundle "primary" "$primary_source"
      run_bundle "persona" "$persona_source"

      if [ "$format" = "json" ]; then
        ${pkgs.jq}/bin/jq -n \
          --arg runtime_dir "$runtime_dir" \
          --arg registry_dir "$registry_dir" \
          --arg archive_dir "$archive_dir" \
          --arg primary_source "$primary_source" \
          --arg persona_source "$persona_source" \
          --slurpfile primary_readiness "$tmpdir/primary-readiness.json" \
          --slurpfile primary_inventory "$tmpdir/primary-inventory.json" \
          --slurpfile primary_audit "$tmpdir/primary-audit.json" \
          --slurpfile persona_readiness "$tmpdir/persona-readiness.json" \
          --slurpfile persona_inventory "$tmpdir/persona-inventory.json" \
          --slurpfile persona_audit "$tmpdir/persona-audit.json" \
          '{
            summary: "Combined skill-manager audit across configured source libraries",
            runtime_dir: $runtime_dir,
            registry_dir: $registry_dir,
            archive_dir: $archive_dir,
            sources: {
              primary: {
                source_repo: $primary_source,
                readiness: $primary_readiness[0],
                inventory: $primary_inventory[0],
                audit: $primary_audit[0]
              },
              persona: {
                source_repo: $persona_source,
                readiness: $persona_readiness[0],
                inventory: $persona_inventory[0],
                audit: $persona_audit[0]
              }
            }
          }'
        exit 0
      fi

      echo "== primary source =="
      echo "$primary_source"
      ${pkgs.jq}/bin/jq -r '
        .summary,
        (.sections[] | "## " + .title, (.lines[]?))
      ' "$tmpdir/primary-audit.json"
      echo
      echo "== persona source =="
      echo "$persona_source"
      ${pkgs.jq}/bin/jq -r '
        .summary,
        (.sections[] | "## " + .title, (.lines[]?))
      ' "$tmpdir/persona-audit.json"
    '')
  ];

  # Merge managed config into the live openclaw.json on each activation.
  # Existing runtime keys (gateway.auth, wizard, meta) survive the merge;
  # managed keys always win so the Nix definition stays the source of truth.
  home.activation.openclawConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    config_dir="$HOME/.openclaw"
    config_file="$config_dir/openclaw.json"
    mkdir -p "$config_dir"

    if [ -f "$config_file" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
        "$config_file" \
        ${openclawConfigFile} \
        > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
    else
      cp ${openclawConfigFile} "$config_file"
    fi
    chmod 600 "$config_file"
  '';

  home.activation.openclawClawhub = lib.hm.dag.entryAfter [ "openclawConfig" ] ''
    npm_prefix="$HOME/.npm-global"
    clawhub_bin="$npm_prefix/bin/clawhub"

    mkdir -p "$npm_prefix"

    if [ ! -x "$clawhub_bin" ]; then
      echo "Installing clawhub into $npm_prefix ..."
      ${pkgs.nodejs}/bin/npm install --global --prefix "$npm_prefix" clawhub
    fi
  '';
}
