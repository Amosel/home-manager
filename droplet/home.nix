{ pkgs, username ? "root", homeDirectory ? "/root", ... }:

{
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    bat
    btop
    dotnet-sdk
    delta
    eza
    fd
    ffmpeg
    findutils
    fzf
    gh
    git
    git-filter-repo
    git-lfs
    gitleaks
    glab
    gogcli
    grpcurl
    jq
    libusb1
    mermaid-cli
    mitmproxy
    ngrok
    neovim
    nodejs
    ocrmypdf
    p7zip
    pipx
    poppler-utils
    postgresql_14
    python311
    rbenv
    ripgrep
    shellcheck
    slackdump
    socat
    sox
    speedtest-cli
    tmux
    tree
    wget
    zbar
    zig
    _1password-cli
    flutter
    google-cloud-sdk
    highlight
    trunk-io
    cargo
    rustc
    cargo-binstall
    cargo-generate
    cargo-udeps
    just
    mdbook
    mdbook-admonish
    mdbook-katex
    texliveSmall
    yq-go
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less -FR";
  };

  programs.bash = {
    enable = true;
    historyControl = [ "ignoreboth" ];
    historyFileSize = 50000;
    historySize = 50000;
    shellAliases = rec {
      cat = "bat --paging=never";
      grep = "rg";
      l = "eza -la --git --group-directories-first";
      ll = "eza -la --git --group-directories-first --time-style=long-iso";
      list-git = l;
      list-git-long-iso = ll;
      v = "nvim";
    };
    initExtra = ''
      shopt -s histappend
      export HISTTIMEFORMAT="%F %T "
    '';
  };

  programs.git = {
    enable = true;
    ignores = [ ".DS_Store" ".direnv/" ".envrc.local" ];
    settings = {
      user = {
        name = "Amos Elmaliah";
        email = "amosel@gmail.com";
      };
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = false;
      rerere.enabled = true;
      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        line-numbers = true;
        side-by-side = true;
      };
    };
  };
}
