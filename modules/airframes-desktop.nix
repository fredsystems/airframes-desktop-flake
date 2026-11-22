# Shared by nixosModules.default and darwinModules.default: both expose
# environment.systemPackages, which is all this needs.
defaultPackageFor:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.airframes-desktop;
in
{
  options.programs.airframes-desktop = {
    enable = lib.mkEnableOption "the Airframes.io desktop app";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackageFor pkgs.stdenv.hostPlatform.system;
      defaultText = lib.literalExpression "airframes-desktop.packages.\${system}.default";
      description = "The airframes-desktop package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
