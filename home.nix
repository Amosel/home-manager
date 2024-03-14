{ config, pkgs, ... }:

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
    fira-code-nerdfont
    yt-dlp
    ffmpeg_5-full
    bun 
    rustup
    mob
    go
    zig
    fnm
    git
    git-lfs
    wget
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
    # Let Home Manager install and manage itself.
    # add incase cargo binary directories are not injected (could have been fixed.)
    CARGO_HOME = "${config.home.homeDirectory}/.cargo";
    CARGO_BIN = "${config.home.homeDirectory}/.cargo/bin";
    FOUNDRY_BIN = "${config.home.homeDirectory}/.foundry/bin";
    PATH = "/usr/local/bin:$CARGO_HOME:$CARGO_BIN:$FOUNDRY_BIN:$PATH";
  };

  programs.home-manager.enable = true;
  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
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

      code="/usr/local/bin/code";
      ollama="/usr/local/bin/ollama";
      # zed="/usr/local/bin/zed";
      # cursor="/usr/local/bin/cursor";
      # foundry="$HOME/.foundry/bin"
    };
    initExtra = ''
      eval "$(fnm env)"
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
      alias = {
        b = "branch";
        bb = "for-each-ref --sort=committerdate refs/heads/ --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'";
        s = "status";
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
