{
  description = "Nix flake for the Airframes.io desktop app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    precommit-base = {
      url = "github:fredsystems/pre-commit-checks";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      precommit-base,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      packageSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      # The dev shell is also useful on platforms the app itself does not
      # ship for (e.g. aarch64-linux).
      devSystems = packageSystems ++ [ "aarch64-linux" ];

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: lib.getName pkg == "airframes-desktop";
        };

      module = import ./modules/airframes-desktop.nix (system: self.packages.${system}.default);
    in
    {
      overlays.default = final: _prev: {
        airframes-desktop = final.callPackage ./pkgs/airframes-desktop { };
      };

      nixosModules.default = module;
      darwinModules.default = module;

      packages = lib.genAttrs packageSystems (
        system:
        let
          airframes-desktop = (pkgsFor system).callPackage ./pkgs/airframes-desktop { };
        in
        {
          inherit airframes-desktop;
          default = airframes-desktop;
        }
      );

      checks = lib.genAttrs devSystems (
        system:
        {
          pre-commit-check = precommit-base.lib.mkCheck {
            inherit system;
            src = ./.;
          };
        }
        // lib.optionalAttrs (self.packages ? ${system}) {
          package = self.packages.${system}.default;
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          vm-test = import ./tests/vm.nix {
            pkgs = pkgsFor system;
            inherit module;
          };
        }
      );

      devShells = lib.genAttrs devSystems (
        system:
        let
          pkgs = pkgsFor system;
          precommit = self.checks.${system}.pre-commit-check;
        in
        {
          default = pkgs.mkShell {
            name = "airframes-desktop-flake";
            packages =
              precommit.enabledPackages
              ++ (with pkgs; [
                curl
                gh
                jq
              ]);
            inherit (precommit) shellHook;
          };
        }
      );
    };
}
