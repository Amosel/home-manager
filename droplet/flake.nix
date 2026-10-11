{
  description = "Home Manager profile for the DigitalOcean Droplet";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [ "1password-cli" "ngrok" "trunk-io" ];
      };
    in {
      homeConfigurations."root@codex-vast-flint-fae5" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          username = "root";
          homeDirectory = "/root";
        };
        modules = [ ./home.nix ];
      };
      homeConfigurations."codex@codex-vast-flint-fae5" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {
          username = "codex";
          homeDirectory = "/home/codex";
        };
        modules = [ ./home.nix ];
      };
    };
}
