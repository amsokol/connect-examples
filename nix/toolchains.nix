# Pinned toolchains overlaid onto nixpkgs (versions from tools.version.toml + Cargo.toml / go.mod / uv.lock).
{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    let
      versions = builtins.fromTOML (builtins.readFile (inputs.self + "/tools.version.toml"));
      bufPin = versions.buf;
      protocGenGoPin = versions."protoc-gen-go";
      protocGenConnectGoPin = versions."protoc-gen-connect-go";
      grpcHealthProbePin = versions."grpc-health-probe";
      golangciLintPin = versions."golangci-lint";
      govulncheckPin = versions.govulncheck;
      cargoAuditPin = versions."cargo-audit";
      pipAuditPin = versions."pip-audit";
      ruffPin = versions.ruff;
      markdownlintCli2Pin = versions."markdownlint-cli2";

      cargoToml = builtins.fromTOML (builtins.readFile (inputs.self + "/Cargo.toml"));
      workspacePackage = cargoToml.workspace.package;

      pyproject = builtins.fromTOML (builtins.readFile (inputs.self + "/pyproject.toml"));
      pythonProjectVersion = pyproject.project.version;

      # Needed inside the nixpkgs overlay for pip-audit (same rule as `python` below).
      pythonAttrName =
        let
          rawFile = builtins.readFile (inputs.self + "/.python-version");
          trimmed =
            if builtins.substring (builtins.stringLength rawFile - 1) 1 rawFile == "\n" then
              builtins.substring 0 (builtins.stringLength rawFile - 1) rawFile
            else
              rawFile;
          segs = builtins.filter builtins.isString (builtins.split "\\." trimmed);
          major = builtins.elemAt segs 0;
          minor = builtins.elemAt segs 1;
        in
        if builtins.length segs < 2 then
          throw ".python-version: expected X.Y (got ${trimmed})"
        else
          "python${major}${minor}";

      # Fail evaluation if tools.version.toml drifts from pyproject.toml dependency-groups.dev.
      assertDevPin =
        name: pinVersion:
        let
          specs = pyproject."dependency-groups".dev or [ ];
          prefix = "${name}==";
          matches = builtins.filter (s: builtins.substring 0 (builtins.stringLength prefix) s == prefix) specs;
          expected = "${name}==${pinVersion}";
        in
        if matches == [ expected ] then
          true
        else
          throw "tools.version.toml [${name}] (${pinVersion}) must match pyproject.toml dependency-groups.dev entry `${expected}` (found: ${builtins.toJSON matches})";

      _assertRuff = assertDevPin "ruff" versions.ruff.version;
      _assertPipAudit = assertDevPin "pip-audit" versions."pip-audit".version;

      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (import inputs.rust-overlay)
          (final: prev: {
            buf = prev.buf.overrideAttrs (_old: {
              version = bufPin.version;
              src = prev.fetchFromGitHub {
                owner = "bufbuild";
                repo = "buf";
                tag = "v${bufPin.version}";
                hash = bufPin.hash;
              };
              vendorHash = bufPin.vendorHash;
            });

            protoc-gen-go = prev.protoc-gen-go.overrideAttrs (_old: {
              version = protocGenGoPin.version;
              src = prev.fetchFromGitHub {
                owner = "protocolbuffers";
                repo = "protobuf-go";
                rev = "v${protocGenGoPin.version}";
                hash = protocGenGoPin.hash;
              };
              vendorHash = protocGenGoPin.vendorHash;
            });

            protoc-gen-connect-go = prev.protoc-gen-connect-go.overrideAttrs (_old: {
              version = protocGenConnectGoPin.version;
              src = prev.fetchFromGitHub {
                owner = "connectrpc";
                repo = "connect-go";
                tag = "v${protocGenConnectGoPin.version}";
                hash = protocGenConnectGoPin.hash;
              };
              vendorHash = protocGenConnectGoPin.vendorHash;
            });

            grpc-health-probe = prev.grpc-health-probe.overrideAttrs (_old: {
              version = grpcHealthProbePin.version;
              src = prev.fetchFromGitHub {
                owner = "grpc-ecosystem";
                repo = "grpc-health-probe";
                tag = "v${grpcHealthProbePin.version}";
                hash = grpcHealthProbePin.hash;
              };
              vendorHash = grpcHealthProbePin.vendorHash;
            });

            golangci-lint = prev.golangci-lint.overrideAttrs (_old: {
              version = golangciLintPin.version;
              src = prev.fetchFromGitHub {
                owner = "golangci";
                repo = "golangci-lint";
                tag = "v${golangciLintPin.version}";
                hash = golangciLintPin.hash;
              };
              vendorHash = golangciLintPin.vendorHash;
            });

            govulncheck = prev.govulncheck.overrideAttrs (_old: {
              version = govulncheckPin.version;
              src = prev.fetchFromGitHub {
                owner = "golang";
                repo = "vuln";
                tag = "v${govulncheckPin.version}";
                hash = govulncheckPin.hash;
              };
              vendorHash = govulncheckPin.vendorHash;
            });

            cargo-audit =
              let
                version = cargoAuditPin.version;
                src = prev.fetchCrate {
                  pname = "cargo-audit";
                  inherit version;
                  hash = cargoAuditPin.hash;
                };
              in
              prev.cargo-audit.overrideAttrs (_old: {
                inherit version src;
                cargoHash = cargoAuditPin.cargoHash;
                cargoDeps = prev.rustPlatform.fetchCargoVendor {
                  inherit src;
                  name = "cargo-audit-${version}";
                  hash = cargoAuditPin.cargoHash;
                };
              });

            pip-audit =
              let
                py =
                  prev.${pythonAttrName}
                    or (throw "nixpkgs has no pkgs.${pythonAttrName} (from .python-version)");
                pipAuditPkg = py.pkgs.buildPythonPackage {
                  pname = "pip-audit";
                  version = pipAuditPin.version;
                  format = "wheel";
                  src = prev.fetchurl {
                    url = pipAuditPin.url;
                    hash = pipAuditPin.hash;
                  };
                  dependencies = with py.pkgs; [
                    cachecontrol
                    cyclonedx-python-lib
                    filelock
                    html5lib
                    packaging
                    pip
                    pip-api
                    pip-requirements-parser
                    platformdirs
                    requests
                    rich
                    tomli
                    tomli-w
                  ];
                  pythonImportsCheck = [ "pip_audit" ];
                  doCheck = false;
                };
                # withPackages so `python -m pip` (used by pip_api) sees pip.
                env = py.withPackages (_ps: [
                  pipAuditPkg
                  py.pkgs.pip
                ]);
              in
              prev.runCommand "pip-audit-${pipAuditPin.version}"
                {
                  nativeBuildInputs = [ prev.makeWrapper ];
                  meta.mainProgram = "pip-audit";
                }
                ''
                  mkdir -p "$out/bin"
                  makeWrapper "${env}/bin/pip-audit" "$out/bin/pip-audit"
                '';

            ruff =
              let
                version = ruffPin.version;
                src = prev.fetchFromGitHub {
                  owner = "astral-sh";
                  repo = "ruff";
                  tag = version;
                  hash = ruffPin.hash;
                };
              in
              prev.ruff.overrideAttrs (_old: {
                inherit version src;
                cargoHash = ruffPin.cargoHash;
                cargoDeps = prev.rustPlatform.fetchCargoVendor {
                  inherit src;
                  name = "ruff-${version}";
                  hash = ruffPin.cargoHash;
                };
              });

            markdownlint-cli2 = prev.markdownlint-cli2.overrideAttrs (_old: {
              version = markdownlintCli2Pin.version;
              src = prev.fetchFromGitHub {
                owner = "DavidAnson";
                repo = "markdownlint-cli2";
                tag = "v${markdownlintCli2Pin.version}";
                hash = markdownlintCli2Pin.hash;
              };
              npmDepsHash = markdownlintCli2Pin.npmDepsHash;
            });
          })
        ];
      };

      inherit (pkgs) lib;

      rustToolchain =
        let
          stable = pkgs.rust-bin.stable;
          ver = workspacePackage.rust-version;
        in
        if stable ? ${ver} then
          stable.${ver}.default.override {
            extensions = [ "clippy" ];
            targets = [
              "x86_64-unknown-linux-musl"
              "aarch64-unknown-linux-musl"
            ];
          }
        else
          throw "rust-overlay has no stable.${ver} (from Cargo.toml [workspace.package].rust-version)";

      craneLib = (inputs.crane.mkLib pkgs).overrideToolchain rustToolchain;

      rustSrc = craneLib.cleanCargoSource inputs.self;

      # Shared vendor dir for all Rust app packages.
      # Git deps (e.g. mimalloc) come from Cargo.lock via builtins.fetchGit — no Nix pins.
      cargoVendorDir = craneLib.vendorCargoDeps {
        src = rustSrc;
      };

      goModVersion =
        let
          inherit (lib) splitString hasPrefix removePrefix;
          lines = splitString "\n" (builtins.readFile (inputs.self + "/go.mod"));
          goLine = lib.findFirst (l: hasPrefix "go " l) null lines;
        in
        if goLine == null then
          throw "go.mod: missing 'go X.Y' line"
        else
          removePrefix "go " goLine;

      goAttrName =
        let
          parts = lib.splitString "." goModVersion;
          major = builtins.elemAt parts 0;
          minor = builtins.elemAt parts 1;
        in
        "go_${major}_${minor}";

      go =
        let
          pkg = pkgs.${goAttrName} or (throw "nixpkgs has no pkgs.${goAttrName} (from go.mod)");
        in
        if lib.versionAtLeast pkg.version goModVersion then
          pkg
        else
          throw "nixpkgs ${goAttrName} is ${pkg.version}, but go.mod requires >= ${goModVersion}";

      # Workspace tests live in nix/test.nix; keep app builds from re-running them.
      buildGoModule =
        args:
        (pkgs.buildGoModule.override { inherit go; }) (
          args
          // {
            env = (args.env or { }) // {
              GOTOOLCHAIN = "local";
            };
            doCheck = if args ? doCheck then args.doCheck else false;
          }
        );

      goModuleSrcPatterns = [
        "^go\\.mod$"
        "^go\\.sum$"
        "^go(/.*)?$"
      ];

      goSrc = lib.sourceByRegex inputs.self goModuleSrcPatterns;

      # golangci-lint needs the config next to the module root.
      goLintSrc = lib.sourceByRegex inputs.self (
        goModuleSrcPatterns
        ++ [
          "^\\.golangci\\.yaml$"
        ]
      );

      # Fixed-output hash of `go mod vendor` for the root module (tools.version.toml [go]).
      goVendorHash = versions.go.vendorHash;

      # --- Python (uv.lock via uv2nix; interpreter from .python-version / pythonAttrName above) ---
      python =
        pkgs.${pythonAttrName}
          or (throw "nixpkgs has no pkgs.${pythonAttrName} (from .python-version)");

      pythonWorkspace = inputs.uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = inputs.self;
      };

      pythonOverlay = pythonWorkspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };

      pythonSet = (pkgs.callPackage inputs.pyproject-nix.build.packages {
        inherit python;
      }).overrideScope (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.wheel
          pythonOverlay
        ]
      );

      pythonSrc = lib.sourceByRegex inputs.self [
        "^pyproject\\.toml$"
        "^uv\\.lock$"
        "^python(/.*)?$"
      ];

      mdLintSrc = lib.sourceByRegex inputs.self [
        "^README\\.md$"
        "^\\.markdownlint-cli2\\.yaml$"
      ];

      # Realize a check derivation via `nix run` (shared by lint / vuln / buf).
      appFromCheck =
        name: drv:
        pkgs.writeShellApplication {
          inherit name;
          text = ''
            echo "hermetic ${name} passed: ${drv}"
          '';
          meta.description = "Realize hermetic check ${name}";
        };
    in
    assert _assertRuff;
    assert _assertPipAudit;
    {
      _module.args = {
        inherit
          versions
          pkgs
          workspacePackage
          pythonProjectVersion
          rustToolchain
          craneLib
          rustSrc
          cargoVendorDir
          go
          buildGoModule
          goSrc
          goLintSrc
          goVendorHash
          python
          pythonWorkspace
          pythonSet
          pythonSrc
          mdLintSrc
          appFromCheck
          ;
      };
    };
}
