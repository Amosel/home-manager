{ ... }:

{
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
      aliases = {
        co = "pr checkout";
      };
    };
  };

  programs.git = {
    enable = true;
    ignores = [
      ".DS_Store"
      ".direnv/"
      ".envrc.local"
      ".mise.local.toml"
      "**/.claude/settings.local.json"
    ];
    settings = {
      user = {
        name = "Amos Elmaliah";
        email = "amosel@gmail.com";
      };
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = false;
      rerere.enabled = true;
      merge.conflictstyle = "zdiff3";
      diff = {
        algorithm = "histogram";
        colorMoved = "default";
      };
      core = {
        excludesfile = "/Users/amoselmaliah/.gitignore_global";
        pager = "delta";
      };
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        line-numbers = true;
        side-by-side = true;
      };
      alias = {
        b = "branch";
        bb = "for-each-ref --sort='-committerdate' --format='%(color:bold blue)%(refname:short)%(color:reset) - %(color:bold green)%(committerdate:relative)%(color:reset) - %(color:bold red)%(authorname)%(color:reset) (%(color:bold yellow)%(subject)%(color:reset))' refs/heads/ --count 10";
        s = "status --short --branch";
        div = "!git log --left-right --graph --cherry-pick --oneline HEAD...origin/$(git rev-parse --abbrev-ref HEAD)";
        a = "!git add . && git status";
        au = "!git add -u . && git status";
        aa = "!git add . && git add -u . && git status";
        ac = "!git add . && git commit";
        acm = "!git add . && git commit -m";
        l = "log --graph --pretty=format':%C(yellow)%h%Cblue%d%Creset %s %C(white) %an, %ar%Creset'";
        la = "log --graph --all --pretty=format:'%C(yellow)%h%C(cyan)%d%Creset %s %C(white)- %an, %ar%Creset'";
        ll = "log --stat --abbrev-commit";
        authors = "log --format='%aN' | sort | uniq -c | sort -rn";
        d = "diff --color-words";
        dh = "diff --color-words HEAD";
      };
    };
  };
}
