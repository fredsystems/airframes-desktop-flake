{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  desktop-file-utils,
  dpkg,
  wrapGAppsHook3,
  cairo,
  dbus,
  gdk-pixbuf,
  glib,
  glib-networking,
  gst_all_1,
  gtk3,
  libayatana-appindicator,
  libsoup_3,
  webkitgtk_4_1,
  xdg-utils,
  version,
  source,
  meta,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "airframes-desktop";
  inherit version meta;

  src = fetchurl { inherit (source) url hash; };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    wrapGAppsHook3
  ];

  # Everything the binary links against (DT_NEEDED). autoPatchelfHook fails
  # the build if any of them cannot be resolved from this list.
  buildInputs = [
    cairo
    dbus
    gdk-pixbuf
    glib
    gtk3
    libsoup_3
    stdenv.cc.cc.lib
    webkitgtk_4_1
  ]
  # Not linked, but required at runtime: TLS for libsoup (glib-networking,
  # picked up by wrapGAppsHook3 via GIO_EXTRA_MODULES) and media playback
  # inside the webview (gstreamer plugins, via GST_PLUGIN_SYSTEM_PATH_1_0).
  ++ [
    glib-networking
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
  ];

  # The tray icon library is dlopen()ed by Tauri, so it never appears in
  # DT_NEEDED; adding it here puts it on the binary's RUNPATH.
  runtimeDependencies = [ libayatana-appindicator ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 usr/bin/airframes-desktop "$out/bin/airframes-desktop"
    cp -r usr/share "$out/share"

    runHook postInstall
  '';

  # Opening links in the browser goes through xdg-open.
  preFixup = ''
    gappsWrapperArgs+=(--suffix PATH : ${lib.makeBinPath [ xdg-utils ]})
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ desktop-file-utils ];

  installCheckPhase = ''
    runHook preInstallCheck

    debVersion="$(dpkg-deb -f "$src" Version)"
    if [ "$debVersion" != "${finalAttrs.version}" ]; then
      echo "sources.json says ${finalAttrs.version} but the .deb is $debVersion" >&2
      exit 1
    fi

    unwrapped="$out/bin/.airframes-desktop-wrapped"
    [ -x "$unwrapped" ] || { echo "missing wrapped binary $unwrapped" >&2; exit 1; }

    lddOut="$(${lib.getBin stdenv.cc.libc}/bin/ldd "$unwrapped")"
    if echo "$lddOut" | grep 'not found'; then
      echo "unresolved shared libraries" >&2
      exit 1
    fi

    rpath="$(patchelf --print-rpath "$unwrapped")"
    case ":$rpath:" in
      *:${libayatana-appindicator}/lib:*) ;;
      *) echo "libayatana-appindicator missing from RUNPATH: $rpath" >&2; exit 1 ;;
    esac
    [ -e ${libayatana-appindicator}/lib/libayatana-appindicator3.so.1 ] || {
      echo "libayatana-appindicator3.so.1 not found" >&2
      exit 1
    }

    grep -q ${glib-networking}/lib/gio/modules "$out/bin/airframes-desktop" || {
      echo "wrapper does not put glib-networking on GIO_EXTRA_MODULES" >&2
      exit 1
    }

    desktop-file-validate "$out/share/applications/Airframes.desktop"
    for size in 32x32 128x128; do
      [ -f "$out/share/icons/hicolor/$size/apps/airframes-desktop.png" ] || {
        echo "missing $size icon" >&2
        exit 1
      }
    done

    runHook postInstallCheck
  '';
})
