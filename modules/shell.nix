{ config, lib, ... }:

let
  commonShellAliases = {
    l = "lla -T --no-dotfiles";
    ll = "lla -l --no-dotfiles";
    la = "lla -l --all";
    lt = "lla -t -d 2 --no-dotfiles";
    ltt = "lla -t -d 4 --no-dotfiles";
    ld = "lla -T --dirs-only --no-dotfiles";
    lf = "lla -T --files-only --no-dotfiles";
    lhide = "lla -T --dotfiles-only";
    lg = "lla -G --no-dotfiles";
    lga = "lla -G --all";
    lnew = "lla -T -s date -r --no-dotfiles";
    lold = "lla -T -s date --no-dotfiles";
    lbig = "lla -T -s size -r --no-dotfiles";
    ltime = "lla --timeline --no-dotfiles";
    lgrep = "lla --search";
    ljson = "lla --json --pretty";
    lraw = "/bin/ls";
    eg = "eza -la --git --group-directories-first --time-style=relative";
    ex = "eza -la --extended --flags --time-style=long-iso";
    er = "eza -la --git-repos --group-directories-first";
    cat = "bat --paging=never";
    grep = "rg";
    mkdir = "mkdir -pv";
    ping = "ping -c 5";
    HEAD = "curl -I";
    v = "nvim";
    c = "codex";
    daml = "~/.daml/bin/daml";
    sed = "~/.nix-profile/bin/sed";
    scan-fast = "trivy repo .";
    scan-deep = "npx megalinter-runner --flavor security";
    history-stat = "history 0 | awk '{print $2}' | sort | uniq -c | sort -n -r | tail -10";
  };

  shellInit = ''
    eval "$(fnm env --use-on-cd --version-file-strategy=recursive)"

    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:$PATH"
    export PATH="$HOME/.npm-global/bin:$PATH"
    export PATH="$HOME/.opencode/bin:$HOME/.bun/bin:$HOME/.cargo/bin:$HOME/.foundry/bin:$HOME/go/bin:$HOME/.pub-cache/bin:$PATH"
    export PATH="$JAVA_HOME:$JAVA_HOME/bin:$ANDROID_HOME:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$PATH"
    export PATH="$HOME/.deno/bin:$HOME/.modular/bin:$HOME/flutter/bin:$HOME/.daml/bin:/opt/canton/bin:$PATH"

    ls() {
      if [ "$#" -eq 0 ]; then
        command lla -T --no-dotfiles
      else
        command /bin/ls "$@"
      fi
    }

    hms() {
      command home-manager switch --flake "${config.home.homeDirectory}/.config/home-manager#amoselmaliah" "$@"
    }
  '';
in
{
  # Keep npm-installed CLIs visible outside interactive shell init as well
  # so GUI-launched tools and subprocesses resolve the same binaries.
  home.sessionPath = [
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.opencode/bin"
    "${config.home.homeDirectory}/.bun/bin"
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/.foundry/bin"
    "${config.home.homeDirectory}/go/bin"
    "${config.home.homeDirectory}/.pub-cache/bin"
    "${config.home.homeDirectory}/.deno/bin"
    "${config.home.homeDirectory}/.modular/bin"
    "${config.home.homeDirectory}/flutter/bin"
    "${config.home.homeDirectory}/.daml/bin"
    "/opt/canton/bin"
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin"
    "${config.home.homeDirectory}/Library/Android/sdk/tools"
    "${config.home.homeDirectory}/Library/Android/sdk/platform-tools"
  ];

  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.npm-global
  '';

  home.file.".config/lla/config.toml".text = ''
    default_sort = "name"
    default_format = "default"
    show_icons = true
    include_dirs = false
    permission_format = "symbolic"
    theme = "default"
    enabled_plugins = []
    plugins_dir = "~/.config/lla/plugins"
    default_depth = 3

    [sort]
    dirs_first = true
    case_sensitive = false
    natural = true

    [filter]
    case_sensitive = false
    no_dotfiles = false

    [formatters.tree]
    max_lines = 20000

    [formatters.grid]
    ignore_width = false
    max_width = 200

    [listers.recursive]
    max_entries = 20000

    [listers.fuzzy]
    ignore_patterns = ["node_modules", "target", ".git", ".idea", ".vscode"]
  '';

  home.activation.npmGlobalPrefix = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.npm-global"
  '';

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less -FR";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git";
    BAT_THEME = "TwoDark";
    JAVA_HOME = "/Applications/Android Studio.app/Contents/jbr/Contents/Home";
    ANDROID_HOME = "${config.home.homeDirectory}/Library/Android/sdk";
    GOPATH = "${config.home.homeDirectory}/go";
    DENO_INSTALL = "${config.home.homeDirectory}/.deno";
    MODULAR_HOME = "${config.home.homeDirectory}/.modular";
    OLLAMA_MODELS = "${config.home.homeDirectory}/models";
    BB_HOME = "${config.home.homeDirectory}/.bb";
    NARGO_HOME = "${config.home.homeDirectory}/.nargo";
    NARGO_BIN_DIR = "${config.home.homeDirectory}/.nargo/bin";
    DAML_SDK_HOME = "${config.home.homeDirectory}/.daml";
    CANTON_HOME = "/opt/canton";
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    defaultKeymap = "emacs";
    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };
    shellAliases = commonShellAliases;
    initContent = ''
      ${shellInit}
      setopt HIST_IGNORE_ALL_DUPS
      setopt INC_APPEND_HISTORY

      eval "$(zoxide init zsh)"
    '';
    loginExtra = ''
      bindkey -e
    '';
  };

  programs.bash = {
    enable = true;
    historyControl = [ "ignoreboth" ];
    historyFileSize = 20000;
    historySize = 10000;
    shellAliases = commonShellAliases;
    initExtra = ''
      shopt -s histappend
      export HISTTIMEFORMAT="%F %T "
      PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
      ${shellInit}

      eval "$(zoxide init bash)"
    '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      command_timeout = 1000;
      character = {
        success_symbol = "[>](bold green)";
        error_symbol = "[>](bold red)";
      };
      directory = {
        truncation_length = 4;
        truncate_to_repo = false;
      };
      git_branch.format = "[$symbol$branch]($style) ";
      git_status.disabled = false;
      package.disabled = true;
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
  };

  programs.zoxide.enable = true;

  programs.bat.enable = true;
  programs.eza = {
    enable = true;
    enableZshIntegration = false;
    enableBashIntegration = false;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      auto_sync = false;
      update_check = false;
      style = "compact";
      inline_height = 20;
    };
  };

  programs.tmux = {
    enable = true;
    clock24 = true;
    escapeTime = 0;
    historyLimit = 100000;
    keyMode = "emacs";
    mouse = true;
    prefix = "C-a";
    sensibleOnTop = true;
    terminal = "screen-256color";
    extraConfig = ''
      set -g base-index 1
      setw -g pane-base-index 1
      set -g renumber-windows on
      set -g set-clipboard on
      set -g status-interval 5
      set -g status-position bottom
      set -g status-left-length 30
      set -g status-right-length 80
      set -g status-left "#S "
      set -g status-right "#(whoami) #[fg=colour244]%Y-%m-%d %H:%M"
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "tmux reloaded"
    '';
  };
}
