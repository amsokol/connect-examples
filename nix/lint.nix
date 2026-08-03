# Hermetic language + Markdown linters (Nix sandbox). Protobuf: apps.lint-proto in nix/buf.nix.
{ ... }:
{
  perSystem =
    {
      config,
      pkgs,
      buildGoModule,
      goLintSrc,
      goVendorHash,
      craneLib,
      rustSrc,
      cargoVendorDir,
      workspacePackage,
      pythonSrc,
      mdLintSrc,
      appFromCheck,
      ...
    }:
    let
      go-lint = buildGoModule {
        pname = "go-lint";
        version = workspacePackage.version;
        src = goLintSrc;
        vendorHash = goVendorHash;
        nativeBuildInputs = [ pkgs.golangci-lint ];
        buildPhase = ''
          runHook preBuild
          export HOME="$TMPDIR"
          export GOLANGCI_LINT_CACHE="$TMPDIR/golangci-lint"
          golangci-lint run --issues-exit-code=1 ./...
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

      python-lint = pkgs.stdenvNoCC.mkDerivation {
        pname = "python-lint";
        version = workspacePackage.version;
        src = pythonSrc;
        dontConfigure = true;
        dontBuild = true;
        nativeBuildInputs = [ pkgs.ruff ];
        doCheck = true;
        checkPhase = ''
          runHook preCheck
          ruff check python
          ruff format --check python/echo
          runHook postCheck
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          touch "$out/ok"
          runHook postInstall
        '';
      };

      rustLintArtifacts = craneLib.buildDepsOnly {
        pname = "rust-lint";
        version = workspacePackage.version;
        src = rustSrc;
        inherit cargoVendorDir;
      };

      rust-lint = craneLib.cargoClippy {
        pname = "rust-lint";
        version = workspacePackage.version;
        src = rustSrc;
        inherit cargoVendorDir;
        cargoArtifacts = rustLintArtifacts;
        cargoClippyExtraArgs = "--workspace -- --deny warnings";
      };

      md-lint = pkgs.stdenvNoCC.mkDerivation {
        pname = "md-lint";
        version = workspacePackage.version;
        src = mdLintSrc;
        dontConfigure = true;
        dontBuild = true;
        nativeBuildInputs = [ pkgs.markdownlint-cli2 ];
        doCheck = true;
        checkPhase = ''
          runHook preCheck
          markdownlint-cli2
          runHook postCheck
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          touch "$out/ok"
          runHook postInstall
        '';
      };

      # Realizes buf lint + language/Markdown linters in the sandbox.
      lint-all = pkgs.writeShellApplication {
        name = "lint-all";
        text = ''
          echo "hermetic lints passed:"
          echo "  proto:   ${config.checks.lint-proto}"
          echo "  go:      ${go-lint}"
          echo "  python:  ${python-lint}"
          echo "  rust:    ${rust-lint}"
          echo "  md:      ${md-lint}"
        '';
        meta.description = "Run all hermetic linters";
      };
    in
    {
      checks = {
        inherit go-lint python-lint rust-lint md-lint;
      };

      apps = {
        lint-go = {
          type = "app";
          program = "${appFromCheck "lint-go" go-lint}/bin/lint-go";
          meta.description = "Hermetic golangci-lint";
        };
        lint-python = {
          type = "app";
          program = "${appFromCheck "lint-python" python-lint}/bin/lint-python";
          meta.description = "Hermetic ruff check + format";
        };
        lint-rust = {
          type = "app";
          program = "${appFromCheck "lint-rust" rust-lint}/bin/lint-rust";
          meta.description = "Hermetic cargo clippy";
        };
        lint-md = {
          type = "app";
          program = "${appFromCheck "lint-md" md-lint}/bin/lint-md";
          meta.description = "Hermetic markdownlint-cli2";
        };
        lint-all = {
          type = "app";
          program = "${lint-all}/bin/lint-all";
          meta.description = "Run all hermetic linters";
        };
      };
    };
}
