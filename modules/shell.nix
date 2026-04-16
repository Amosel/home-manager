{ config, lib, ... }:

let
  commonShellAliases = {
    ls = "eza --group-directories-first";
    ll = "eza -lah --git --group-directories-first";
    la = "eza -lah --all --group-directories-first";
    cat = "bat --paging=never";
    grep = "rg";
    mkdir = "mkdir -pv";
    ping = "ping -c 5";
    HEAD = "curl -I";
    v = "nvim";
    c = "codex";
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
    export PATH="$HOME/.deno/bin:$HOME/.modular/bin:$HOME/.daml/bin:/opt/canton/bin:$PATH"
  '';
in
{
  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.npm-global
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
  programs.eza.enable = true;

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
