# airframes-desktop-flake

A Nix flake for the [Airframes.io](https://airframes.io) desktop app.

On Linux it repackages the upstream `.deb` against nixpkgs' own WebKitGTK,
GTK and libsoup, rather than shipping the AppImage's bundled copies. On macOS
it installs the upstream universal `.app` bundle unchanged.

| System           | Upstream artifact                |
| ---------------- | -------------------------------- |
| `x86_64-linux`   | `Airframes_<version>_amd64.deb`  |
| `aarch64-darwin` | `Airframes_universal.app.tar.gz` |

The app is closed source, so the package is marked `unfree`. The flake's own
`packages` and modules allow it for you; if you use the overlay instead, allow
it in your nixpkgs config.

## Usage

### Try it

```sh
nix run github:airframesio/airframes-desktop-flake
```

### NixOS

```nix
{
  inputs.airframes-desktop.url = "github:airframesio/airframes-desktop-flake";

  outputs = { nixpkgs, airframes-desktop, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        airframes-desktop.nixosModules.default
        { programs.airframes-desktop.enable = true; }
      ];
    };
  };
}
```

### nix-darwin

Same as NixOS, using `airframes-desktop.darwinModules.default`. The app is
installed to `Applications/Airframes.app` in the system profile.

### Home Manager or a plain package list

```nix
home.packages = [ inputs.airframes-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default ];
```

### Overlay

```nix
nixpkgs.overlays = [ inputs.airframes-desktop.overlays.default ];
nixpkgs.config.allowUnfreePredicate = pkg: pkgs.lib.getName pkg == "airframes-desktop";
environment.systemPackages = [ pkgs.airframes-desktop ];
```

## Runtime notes

- **Staying signed in** needs a Secret Service provider (for example
  `services.gnome.gnome-keyring.enable = true;` or KWallet). Without one the
  app works, but asks you to sign in on every launch.
- **The built-in updater** cannot replace files in the Nix store. Updates
  arrive through this flake instead; ignore the in-app prompt.
- **The `airframes://` link handler** is declared in the desktop file. If your
  `~/.config/mimeapps.list` is managed by Home Manager, the app's attempt to
  register itself at startup fails harmlessly; add the association there
  instead if you need it.

## How updates work

`sources.json` holds the version, URLs and hashes. `scripts/update.sh` fills
it in from the GitHub release API, using the sha256 digests GitHub publishes
for each asset, so nothing has to be downloaded.

The `Update to new Airframes release` workflow runs the script when it
receives a `desktop-release` `repository_dispatch` event (sent by the
Airframes release pipeline) or when run by hand. It opens a pull request
that auto-merges once CI passes.

## Testing

CI runs, for every pull request:

- **Build**: `autoPatchelfHook` fails the build if any library the binary
  links against cannot be resolved.
- **Install checks**: `ldd` reports nothing missing, the dlopen()ed tray
  library is on the RUNPATH, the wrapper provides `glib-networking` for TLS,
  the `.deb` version matches `sources.json`, and the desktop file validates.
- **NixOS VM test**: boots X11 with the module enabled, launches the app as a
  normal user and waits until the window exists, the WebKit web process is
  running and the UI has actually painted. A screenshot is uploaded as a
  build artifact.

Run them locally with:

```sh
nix build -L .#checks.x86_64-linux.package
nix build -L .#checks.x86_64-linux.vm-test
```
