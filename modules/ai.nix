{ lib, pkgs, ... }:

let
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
  home.file = {
    ".codex/skills/home-manager-review".source = ../codex-skills/home-manager-review;
  };

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
