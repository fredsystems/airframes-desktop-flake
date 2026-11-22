{
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  version,
  source,
  meta,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "airframes-desktop";
  inherit version meta;

  src = fetchurl { inherit (source) url hash; };

  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;
  # The bundle is code-signed upstream; stripping or patching it would
  # invalidate the signature.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications"
    cp -R Airframes.app "$out/Applications/"
    makeWrapper "$out/Applications/Airframes.app/Contents/MacOS/airframes-desktop" \
      "$out/bin/airframes-desktop"

    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    app="$out/Applications/Airframes.app"
    [ -x "$app/Contents/MacOS/airframes-desktop" ] || {
      echo "missing app executable" >&2
      exit 1
    }
    [ -f "$app/Contents/_CodeSignature/CodeResources" ] || {
      echo "app bundle is not code-signed" >&2
      exit 1
    }

    plistVersion="$(sed -n '/<key>CFBundleShortVersionString<\/key>/{n;s/.*<string>\(.*\)<\/string>.*/\1/p;}' "$app/Contents/Info.plist")"
    if [ "$plistVersion" != "${finalAttrs.version}" ]; then
      echo "sources.json says ${finalAttrs.version} but Info.plist is $plistVersion" >&2
      exit 1
    fi

    runHook postInstallCheck
  '';
})
