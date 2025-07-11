{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchNpmDeps,
  npmHooks,
  nodejs,
  python3,
  pkg-config,
  sqlite,
  zstd,
  stdenv,
  open-policy-agent,
  cctools,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "matrix-authentication-service";
  version = "0.17.1";

  src = fetchFromGitHub {
    owner = "element-hq";
    repo = "matrix-authentication-service";
    tag = "v${finalAttrs.version}";
    hash = "sha256-iBDvvKy5alaieIm+Jv9WnqHVGjItDSvJAk+ClTRj3v0=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-rHlzLawpCD9onhca9NzgUXmA2vDmW48cQrV05qs+tn8=";

  npmDeps = fetchNpmDeps {
    name = "${finalAttrs.pname}-${finalAttrs.version}-npm-deps";
    src = "${finalAttrs.src}/${finalAttrs.npmRoot}";
    hash = "sha256-0rJAU4PZAshTu6KD4EzIltUT8PO4dnWCY5oM3kyxBBk=";
  };

  npmRoot = "frontend";
  npmFlags = [ "--legacy-peer-deps" ];

  nativeBuildInputs = [
    pkg-config
    open-policy-agent
    npmHooks.npmConfigHook
    nodejs
    (python3.withPackages (ps: [ ps.setuptools ])) # Used by gyp
  ] ++ lib.optional stdenv.hostPlatform.isDarwin cctools; # libtool used by gyp;

  buildInputs = [
    sqlite
    zstd
  ];

  env = {
    ZSTD_SYS_USE_PKG_CONFIG = true;
    VERGEN_GIT_DESCRIBE = finalAttrs.version;
  };

  buildNoDefaultFeatures = true;

  buildFeatures = [ "dist" ];

  postPatch = ''
    substituteInPlace crates/config/src/sections/http.rs \
      --replace ./frontend/dist/    "$out/share/$pname/assets/"
    substituteInPlace crates/config/src/sections/templates.rs \
      --replace ./share/templates/    "$out/share/$pname/templates/" \
      --replace ./share/translations/    "$out/share/$pname/translations/" \
      --replace ./share/manifest.json "$out/share/$pname/assets/manifest.json"
    substituteInPlace crates/config/src/sections/policy.rs \
      --replace ./share/policy.wasm "$out/share/$pname/policy.wasm"
  '';

  preBuild = ''
    make -C policies
    (cd "$npmRoot" && npm run build)
  '';

  # Adopted from https://github.com/element-hq/matrix-authentication-service/blob/main/Dockerfile
  postInstall = ''
    install -Dm444 -t "$out/share/$pname"        "policies/policy.wasm"
    install -Dm444 -t "$out/share/$pname/assets" "$npmRoot/dist/"*
    cp -r templates   "$out/share/$pname/templates"
    cp -r translations   "$out/share/$pname/translations"
  '';

  meta = {
    description = "OAuth2.0 + OpenID Provider for Matrix Homeservers";
    homepage = "https://github.com/element-hq/matrix-authentication-service";
    changelog = "https://github.com/element-hq/matrix-authentication-service/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ teutat3s ];
    mainProgram = "mas-cli";
  };
})
