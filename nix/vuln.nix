# Dependency vulnerability scanners.
# - Go / Python: `nix run` apps (need network for the live advisory DB).
# - Rust: hermetic check via crane + pinned rustsec advisory-db flake input.
{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      go,
      goSrc,
      buildGoModule,
      goVendorHash,
      craneLib,
      rustSrc,
      workspacePackage,
      pythonSrc,
      appFromCheck,
      ...
    }:
    let
      # Vendored module tree so govulncheck does not need a module proxy at runtime.
      goVulnTree = buildGoModule {
        pname = "go-vuln-tree";
        version = workspacePackage.version;
        src = goSrc;
        vendorHash = goVendorHash;
        buildPhase = ''
          runHook preBuild
          mkdir -p "$out"
          cp -a . "$out/"
          runHook postBuild
        '';
        installPhase = "runHook preInstall; runHook postInstall";
        dontFixup = true;
        doCheck = false;
      };

      vuln-go = pkgs.writeShellApplication {
        name = "vuln-go";
        runtimeInputs = [
          pkgs.govulncheck
          go
        ];
        text = ''
          export GOTOOLCHAIN=local
          export GOFLAGS="-mod=vendor"
          cd "${goVulnTree}"
          govulncheck ./...
        '';
        meta.description = "govulncheck on the Go workspace (needs network)";
      };

      # Audit locked runtime deps only (exclude the local workspace package).
      vuln-python = pkgs.writeShellApplication {
        name = "vuln-python";
        runtimeInputs = [
          pkgs.pip-audit
          pkgs.uv
        ];
        text = ''
          export PIP_AUDIT_CACHE_DIR="''${TMPDIR:-/tmp}/pip-audit-cache"
          mkdir -p "$PIP_AUDIT_CACHE_DIR"
          reqs="$(mktemp)"
          trap 'rm -f "$reqs"' EXIT
          # --no-emit-project: skip connect-examples (not on PyPI).
          uv export --directory "${pythonSrc}" --frozen --no-dev --no-emit-project \
            --output-file "$reqs" >/dev/null
          pip-audit -r "$reqs" --disable-pip \
            --cache-dir "$PIP_AUDIT_CACHE_DIR" \
            --progress-spinner=off
        '';
        meta.description = "pip-audit on locked runtime deps from uv.lock (needs network)";
      };

      vuln-rust = craneLib.cargoAudit {
        pname = "vuln-rust";
        version = workspacePackage.version;
        src = rustSrc;
        advisory-db = inputs.advisory-db;
      };

      vuln-all = pkgs.writeShellApplication {
        name = "vuln-all";
        text = ''
          echo "→ vuln-go"
          "${vuln-go}/bin/vuln-go"
          echo "→ vuln-python"
          "${vuln-python}/bin/vuln-python"
          echo "→ vuln-rust (hermetic)"
          echo "hermetic vuln-rust passed: ${vuln-rust}"
          echo "all vulnerability checks passed"
        '';
        meta.description = "Run Go, Python, and Rust vulnerability scanners";
      };
    in
    {
      checks = {
        inherit vuln-rust;
      };

      apps = {
        vuln-go = {
          type = "app";
          program = "${vuln-go}/bin/vuln-go";
          meta.description = "govulncheck on the Go workspace (needs network)";
        };
        vuln-python = {
          type = "app";
          program = "${vuln-python}/bin/vuln-python";
          meta.description = "pip-audit on locked runtime deps from uv.lock (needs network)";
        };
        vuln-rust = {
          type = "app";
          program = "${appFromCheck "vuln-rust" vuln-rust}/bin/vuln-rust";
          meta.description = "Hermetic cargo audit (pinned advisory-db)";
        };
        vuln-all = {
          type = "app";
          program = "${vuln-all}/bin/vuln-all";
          meta.description = "Run Go, Python, and Rust vulnerability scanners";
        };
      };
    };
}
