# Hermetic Go + Rust + Python tests (Nix sandbox + flake toolchains).
{ ... }:
{
  perSystem =
    {
      pkgs,
      buildGoModule,
      goSrc,
      goVendorHash,
      craneLib,
      rustSrc,
      cargoVendorDir,
      workspacePackage,
      pythonSet,
      pythonWorkspace,
      ...
    }:
    let
      go-tests = buildGoModule {
        pname = "go-tests";
        version = workspacePackage.version;
        src = goSrc;
        vendorHash = goVendorHash;
        buildPhase = ''
          runHook preBuild
          go test ./...
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          touch "$out/ok"
          runHook postInstall
        '';
        doCheck = false;
      };

      rustCargoArtifacts = craneLib.buildDepsOnly {
        pname = "rust-tests";
        version = workspacePackage.version;
        src = rustSrc;
        inherit cargoVendorDir;
      };

      rust-tests = craneLib.cargoTest {
        pname = "rust-tests";
        version = workspacePackage.version;
        src = rustSrc;
        inherit cargoVendorDir;
        cargoArtifacts = rustCargoArtifacts;
        cargoExtraArgs = "--locked --workspace";
      };

      pythonVenv = pythonSet.mkVirtualEnv "python-smoke-env" pythonWorkspace.deps.default;

      # Import smoke only (no behavioral client tests yet).
      python-smoke = pkgs.runCommand "python-smoke" { } ''
        ${pythonVenv}/bin/python -c 'import python.echo.client'
        mkdir -p "$out"
        touch "$out/ok"
      '';

      # Building this app realizes go/rust/python checks in the sandbox (no host toolchains).
      test = pkgs.writeShellApplication {
        name = "test";
        text = ''
          echo "hermetic checks passed:"
          echo "  go-tests:     ${go-tests}"
          echo "  rust-tests:   ${rust-tests}"
          echo "  python-smoke: ${python-smoke}"
        '';
        meta.description = "Run hermetic Go + Rust tests and Python import smoke";
      };
    in
    {
      checks = {
        inherit go-tests rust-tests python-smoke;
      };

      apps.test = {
        type = "app";
        program = "${test}/bin/test";
        meta.description = "Run hermetic Go + Rust tests and Python import smoke";
      };
    };
}
