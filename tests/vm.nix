# Boots a minimal X11 desktop with the NixOS module enabled, launches the
# app as a normal user and waits for its window, its WebKit web process, and
# the bundled web UI to actually paint. The VM has no network, so this proves
# the app starts and renders, not that it can reach airframes.io.
{ pkgs, module }:
let
  # A blank window (title bar + empty webview) captures as ~300 distinct
  # colours; the rendered sign-in screen is ~2200. 1000 sits well clear of
  # both, so this only passes once WebKit has painted real content.
  renderedColourThreshold = 1000;
in
pkgs.testers.runNixOSTest {
  name = "airframes-desktop";

  nodes.machine =
    { modulesPath, ... }:
    {
      imports = [
        module
        "${modulesPath}/../tests/common/user-account.nix"
        "${modulesPath}/../tests/common/x11.nix"
      ];

      programs.airframes-desktop.enable = true;
      test-support.displayManager.auto.user = "alice";

      environment.systemPackages = [ pkgs.imagemagick ];

      virtualisation = {
        memorySize = 2048;
        cores = 2;
      };
    };

  testScript = ''
    machine.wait_for_x()
    machine.wait_for_file("/home/alice/.Xauthority")
    machine.succeed("xauth merge ~alice/.Xauthority")
    machine.wait_for_file("/run/user/1000/bus")

    machine.succeed(
        "su - alice -c '"
        "DISPLAY=:0 "
        "XDG_RUNTIME_DIR=/run/user/1000 "
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
        "airframes-desktop >/tmp/airframes.log 2>&1 &'"
    )

    machine.wait_for_window("Airframes")
    machine.wait_until_succeeds("pgrep -u alice -f WebKitWebProcess")

    machine.wait_until_succeeds(
        "test \"$(DISPLAY=:0 import -window root png:- | magick - -format %k info:)\" "
        "-gt ${toString renderedColourThreshold}",
        timeout=120,
    )
    machine.succeed("pgrep -u alice -f '^[^ ]*airframes-desktop'")

    machine.screenshot("airframes")
    print(machine.succeed("cat /tmp/airframes.log"))
  '';
}
