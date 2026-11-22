{
  lib,
  stdenv,
  callPackage,
}:
let
  release = lib.importJSON ../../sources.json;

  meta = {
    description = "Live aircraft tracking from Airframes.io";
    longDescription = ''
      Airframes is the desktop app for Airframes.io: live flights,
      ACARS/VDL/HFDL messages, stations and service status.
    '';
    homepage = "https://airframes.io";
    downloadPage = "https://github.com/airframesio/assets/releases";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    mainProgram = "airframes-desktop";
  };

  args = {
    inherit (release) version;
    inherit meta;
  };
in
if stdenv.hostPlatform.isDarwin then
  callPackage ./darwin.nix (args // { source = release.sources.darwin; })
else
  callPackage ./linux.nix (args // { source = release.sources.${stdenv.hostPlatform.system}; })
