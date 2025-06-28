{
  coreutils,
  fetchFromGitHub,
  gnused,
  lib,
  maven,
  makeWrapper,
  openjdk,
  libGL,
}:

let
  version = "2.0.04";

  src = fetchFromGitHub {
    owner = "Card-Forge";
    repo = "forge";
    rev = "forge-${version}";
    hash = "sha256-Vk5USCXyys9ogP6g6RZbd9CzyfUv8R+agrO2Vl97Mr8=";
  };

  # launch4j downloads and runs a native binary during the package phase.
  patches = [ ./no-launch4j.patch ];

in
maven.buildMavenPackage {
  pname = "forge-mtg";
  inherit version src patches;

  mvnHash = "sha256-5mj7W1m/iGe/Fy2dpiy+7cdqZGAo4cbtOUvMh7eEhbU=";

  doCheck = false; # Needs a running Xorg

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/forge
    cp -a \
      forge-gui-desktop/target/forge.sh \
      forge-gui-desktop/target/forge-gui-desktop-${version}-jar-with-dependencies.jar \
      forge-gui-mobile-dev/target/forge-adventure.sh \
      forge-gui-mobile-dev/target/forge-gui-mobile-dev-${version}-jar-with-dependencies.jar \
      adventure-editor/target/adventure-editor-jar-with-dependencies.jar \
      forge-gui/res \
      $out/share/forge
    cp adventure-editor/target/adventure-editor.sh $out/share/forge/forge-adventure-editor.sh
    runHook postInstall
  '';

  preFixup = ''
    for commandToInstall in forge forge-adventure forge-adventure-editor; do
      chmod 555 $out/share/forge/$commandToInstall.sh
      PREFIX_CMD=""
      if [ "$commandToInstall" = "forge-adventure" ]; then
        PREFIX_CMD="--prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libGL ]}"
      fi

      makeWrapper $out/share/forge/$commandToInstall.sh $out/bin/$commandToInstall \
        --prefix PATH : ${
          lib.makeBinPath [
            coreutils
            openjdk
            gnused
          ]
        } \
        --set JAVA_HOME ${openjdk}/lib/openjdk \
        --set SENTRY_DSN "" \
        $PREFIX_CMD
    done
  '';

  meta = with lib; {
    description = "Magic: the Gathering card game with rules enforcement";
    homepage = "https://card-forge.github.io/forge";
    license = licenses.gpl3Plus;
    maintainers = with maintainers; [ eigengrau ];
  };
}
