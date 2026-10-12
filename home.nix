{...}: {
  imports = [
    ./modules/packages.nix
    ./modules/shell.nix
    ./modules/git.nix
    ./modules/editor.nix
    ./modules/ai.nix
    ./modules/mlx.nix
    ./modules/whisper.nix
  ];

  home.username = "amoselmaliah";
  home.homeDirectory = "/Users/amoselmaliah";
  home.stateVersion = "23.11";
  home.enableNixpkgsReleaseCheck = false;
  programs.home-manager.enable = true;
}
