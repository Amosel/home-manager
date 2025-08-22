{ config, lib, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "amoselmaliah";
  home.homeDirectory = "/Users/amoselmaliah";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  # Disable version mismatch warning between Home Manager and Nixpkgs
  home.enableNixpkgsReleaseCheck = false;

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
    nerd-fonts.fira-code
    yt-dlp
    ffmpeg_6-full
    mob
    # go
    # zig
    fnm
    git
    git-lfs
    # wget
    # android-tools
    # swift-format
    gitui
    lazygit
    watch
    jq
    yq-go
    helmfile
    kubernetes-helm
    fzf
    nixd
    sops
    k9s
    pipx
    httpie
    gawk        # GNU awk
    findutils   # GNU find
    gnused      # GNU sed
    protobuf    # Protocol Buffers
    protols     # Protocol Buffers language server
    buf         # Modern Protocol Buffers toolchain
    lua-language-server
    stylua
    ripgrep
    fd
    # Optional: additional tools that work well with LazyVim
    tree-sitter
    nodejs  # Required for many LSPs and plugins
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/amoselmaliah/etc/profile.d/hm-session-vars.sh
  #

  home.sessionVariables = {
    JAVA_HOME = builtins.toPath "/Applications/Android Studio.app/Contents/jbr/Contents/Home";
    ANDROID_HOME = builtins.toPath "${config.home.homeDirectory}/Library/Android/sdk";
    GOPATH = builtins.toPath "${config.home.homeDirectory}/go";
    # barretenberg
    BB_HOME = "${config.home.homeDirectory}/.bb";
    NARGO_HOME = "${config.home.homeDirectory}/.nargo";
    NARGO_BIN_DIR = "${config.home.homeDirectory}/.nargo/bin";
    DENO_INSTALL = "${config.home.homeDirectory}/.deno";
    OLLAMA_MODELS = "${config.home.homeDirectory}/models";
    MODULAR_HOME = "${config.home.homeDirectory}/.modular";
    # DAML SDK and Canton paths
    DAML_SDK_HOME = "${config.home.homeDirectory}/.daml";
    CANTON_HOME = "/opt/canton";
    PATH = lib.concatStringsSep ":" [
      "/usr/local/bin"
      "${config.home.homeDirectory}/.bun/bin"
      "${config.home.homeDirectory}/.cargo/bin"
      "${config.home.homeDirectory}/.foundry/bin"
      "${config.home.sessionVariables.JAVA_HOME}"
      "${config.home.sessionVariables.JAVA_HOME}/bin"
      "${config.home.homeDirectory}/Library/Android/sdk"
      "${config.home.sessionVariables.ANDROID_HOME}"
      "${config.home.sessionVariables.ANDROID_HOME}/tools"
      "${config.home.sessionVariables.ANDROID_HOME}/platform-tools"
      "${config.home.sessionVariables.GOPATH}/bin"
      "${config.home.sessionVariables.BB_HOME}"
      "${config.home.sessionVariables.NARGO_BIN_DIR}"
      "${config.home.sessionVariables.DENO_INSTALL}/bin"
      "${config.home.sessionVariables.MODULAR_HOME}"
      "${config.home.sessionVariables.MODULAR_HOME}/bin"
      "${config.home.homeDirectory}/flutter/bin"
      "${config.home.homeDirectory}/.pub-cache/bin"
      "${config.home.sessionVariables.DAML_SDK_HOME}/bin"
      "${config.home.sessionVariables.CANTON_HOME}/bin"
      "$PATH"
    ];
    EDITOR = "nvim";
  };

  programs.home-manager.enable = true;
  programs.zsh = {
    enable = true;
    # enableAutosuggestions = true;
    history = {
      size = 10000;
      save = 10000;
    };
    shellAliases = {
      # ls: adding colors, verbose listign
      # and humanize the file sizes:
      ls="ls --color -l -h";
      ll="ls --color=auto -alF";
      # grep: color and show the line
      # number for each match:
      grep="grep -n --color";
      # mkdir: create parent directories
      mkdir="mkdir -pv";
      # ping: stop after 5 pings
      ping="ping -c 5";
      # curl: only display HTTP header
      HEAD="curl -I";
      # Search through your command history and print the top 10 commands
      history-stat= "history 0 | awk '{print $2}' | sort | uniq -c | sort -n -r | head";
      # DAML SDK alias
      daml="~/.daml/bin/daml";
    };
    initExtra = ''
      eval "$(fnm env --use-on-cd --version-file-strategy=recursive)"
      eval "$(/opt/homebrew/bin/brew shellenv)"
      setopt INC_APPEND_HISTORY
    '';
  };
  programs.bash = {
    enable = true;
    initExtra = ''
      shopt -s histappend
      export HISTSIZE=10000
      export HISTFILESIZE=20000
      export HISTCONTROL=ignoreboth
      export HISTIGNORE="ls:bg:fg:exit"
      export HISTTIMEFORMAT="%F %T "
      PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
    '';
  };

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Neovim configuration
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

  programs.starship = {
    enable = true;
    settings = {
      # See docs here: https://starship.rs/config/
      # Symbols config configured in Flake.
      # preset = "tokyo-night";
      battery.display = [{
        threshold = 25; # display battery information if charge is <= 25%
      }];
    };
  };
  fonts.fontconfig.enable = true;

  programs.git = {
    enable = true;
    userName = "Amos Elmaliah";
    userEmail = "amosel@gmail.com";
    extraConfig = {
      init = {
        defaultBranch = "main";
      };
      alias = {
        b = "branch";
        bb = "for-each-ref --sort='-committerdate' --format='%(color:bold blue)%(refname:short)%(color:reset) - %(color:bold green)%(committerdate:relative)%(color:reset) - %(color:bold red)%(authorname)%(color:reset) (%(color:bold yellow)%(subject)%(color:reset))' refs/heads/ --count 10";
        s = "status";
        div = "!git log --left-right --graph --cherry-pick --oneline HEAD...origin/$(git rev-parse --abbrev-ref HEAD)";
        a = "!git add . && git status";
        au = "!git add -u . && git status";
        aa = "!git add . && git add -u . && git status";
        ac = "!git add . && git commit";
        acm = "!git add . && git commit -m";
        l = "log --graph --pretty=format':%C(yellow)%h%Cblue%d%Creset %s %C(white) %an, %ar%Creset'";
        la = "log --graph --all --pretty=format:'%C(yellow)%h%C(cyan)%d%Creset %s %C(white)- %an, %ar%Creset'";
        ll = "log --stat --abbrev-commit";
        authors = "git log --format='%aN' | sort | uniq -c | sort -rn";
        d = "diff --color-words";
        dt = "difftool";
        dh = "diff --color-words head";
      };
      core = {
        excludesfile = "/Users/amoselmaliah/.gitignore_global";
      };
      difftool = {
        Kaleidoscope = {
          cmd = "ksdiff --partial-changeset --relative-path \"$MERGED\" -- \"$LOCAL\" \"$REMOTE\"";
        };
        prompt = "false";
      };
      diff = {
        tool = "Kaleidoscope";
      };
      mergetool = {
        Kaleidoscope = {
          cmd = "ksdiff --merge --output \"$MERGED\" --base \"$BASE\" -- \"$LOCAL\" --snapshot \"$REMOTE\" --snapshot";
          trustExitCode = "true";
        };
        prompt = "false";
      };
      merge = {
        tool = "Kaleidoscope";
      };
      filter = {
        media = {
          required = "true";
          clean = "git media clean %f";
          smudge = "git media smudge %f";
        };
        hawser = {
          clean = "git hawser clean %f";
          smudge = "git hawser smudge %f";
          required = "true";
        };
        lfs = {
          clean = "git lfs clean %f";
          smudge = "git lfs smudge %f";
          required = "true";
        };
      };
      credential = {
        helper = [
          "osxkeychain"
          "!/Library/Java/JavaVirtualMachines/jdk1.8.0_92.jdk/Contents/Home/jre/bin/java -Ddebug=false -Djava.net.useSystemProxies=true -jar /usr/local/Cellar/git-credential-manager/1.6.0/libexec/git-credential-manager-1.6.0.jar"
        ];
      };
    };
  };
}
