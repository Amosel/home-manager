{
  description = "Amos's dotfiles";

  # inputs are other flakes you use within your own flake, dependencies
  # if you will
  inputs = {
    # unstable has the 'freshest' packages you will find, even the AUR
    # doesn't do as good as this, and it's all precompiled.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  # In this context, outputs are mostly about getting home-manager what it
  # needs since it will be the one using the flake
  outputs = { nixpkgs, home-manager, hermes-agent, ... }: {
    homeConfigurations = {
      "amoselmaliah" = home-manager.lib.homeManagerConfiguration {
        # darwin is the macOS kernel and aarch64 means ARM, i.e. apple silicon
        pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        extraSpecialArgs = { inherit hermes-agent; };
        modules = [ ./home.nix ];
      };
    };
  };
}
