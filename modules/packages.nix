{ lib, pkgs, ... }:

let
  chatgptExportPath = "/Users/amoselmaliah/dev/scripts/chatgpt-export-workspaces.sh";
in
{
  home.packages = with pkgs;
    [
      nerd-fonts.fira-code

      git
      git-lfs
      gh

      fnm
      uv
      pipx
      nodejs
      nushell

      ripgrep
      fd
      fzf
      jq
      yq-go
      eza
      bat
      zoxide
      delta
      just
      tmux
      btop
      watch
      wget
      unzip
      httpie
      ncdu
      tree-sitter

      gitui
      lazygit
      lazydocker
      k9s
      helmfile
      kubernetes-helm
      ansible
      yt-dlp
      ffmpeg_6-full
      mob
      protobuf
      protols
      buf
      tika
      sops
      nixd

      lua-language-server
      nodePackages.prettier
      typescript-language-server
      nodePackages.vscode-langservers-extracted
      nodePackages.yaml-language-server
      tailwindcss-language-server
      rust-analyzer
      gopls
      pyright
      bash-language-server
      cmake-language-server
      kotlin-language-server
      nil

      stylua
      shfmt
      alejandra
      black
      isort
      ruff
      hadolint
      shellcheck
      yamllint
      statix
      deadnix

      gawk
      findutils
      gnused

      (pkgs.writeShellScriptBin "protobuf-language-server" ''
        exec ${pkgs.protols}/bin/protols "$@"
      '')
    ]
    ++ lib.optional (builtins.pathExists chatgptExportPath)
      (pkgs.writeShellScriptBin "chatgpt-export-workspaces"
        (builtins.readFile chatgptExportPath));

  fonts.fontconfig.enable = true;
}
