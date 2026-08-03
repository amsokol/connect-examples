# Hermetic Buf lint + codegen (sandbox; protovalidate via tools.version.toml fetch).
{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      versions,
      bufPlugins,
      rustToolchain,
      go,
      python,
      appFromCheck,
      ...
    }:
    let
      inherit (pkgs) lib;

      bufSrc = lib.sourceByRegex inputs.self [
        "^buf\\.gen\\.go\\.yaml$"
        "^buf\\.gen\\.python\\.yaml$"
        "^buf\\.gen\\.rust\\.yaml$"
        "^api(/.*)?$"
      ];

      expectedGo = inputs.self + "/go/api";
      expectedPython = inputs.self + "/python/gen";
      expectedRust = inputs.self + "/rust/api/gen";

      protovalidatePin = versions.protovalidate;
      protovalidate = pkgs.fetchFromGitHub {
        owner = "bufbuild";
        repo = "protovalidate";
        tag = "v${protovalidatePin.version}";
        hash = protovalidatePin.hash;
      };

      # Match Native CI: py plugins omit package markers.
      ensurePythonInit = ''
        find python/gen -type d -print0 | while IFS= read -r -d "" d; do
          if [[ ! -f "$d/__init__.py" ]]; then
            printf '%s\n' 'from __future__ import annotations' > "$d/__init__.py"
          fi
        done
      '';

      # Offline workspace: api + pinned protovalidate module (no BSR network).
      setupBufWorkspace = ''
        export HOME="$TMPDIR/home"
        export BUF_CACHE_DIR="$TMPDIR/buf-cache"
        mkdir -p "$HOME" "$BUF_CACHE_DIR"
        cp -r --no-preserve=mode "$src"/. .
        mkdir -p third_party/protovalidate
        cp -a ${protovalidate}/proto/protovalidate/. third_party/protovalidate/
        cat > buf.yaml <<'EOF'
        version: v2
        modules:
          - path: .
            includes:
              - api
          - path: third_party/protovalidate
            name: buf.build/bufbuild/protovalidate
        lint:
          use:
            - STANDARD
        breaking:
          use:
            - FILE
        EOF
        # Strip leading spaces left by Nix indented-string formatting in the YAML above.
        sed -i 's/^        //' buf.yaml
      '';

      runLint = ''
        buf lint --path api
      '';

      runGenerate = ''
        buf generate --template buf.gen.go.yaml --path api
        buf generate --template buf.gen.python.yaml --include-imports --path api
        buf generate --template buf.gen.rust.yaml --path api
        ${ensurePythonInit}
      '';

      # Hermetic lint on the flake source snapshot (dirty tracked files included;
      # untracked files are excluded).
      lint-proto = pkgs.stdenvNoCC.mkDerivation {
        name = "buf-lint";
        src = bufSrc;
        nativeBuildInputs = [ pkgs.buf ];
        buildPhase = ''
          runHook preBuild
          ${setupBufWorkspace}
          ${runLint}
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          touch "$out/ok"
          runHook postInstall
        '';
      };

      # Hermetic codegen → store paths for go/api, python/gen, rust/api/gen.
      generated = pkgs.stdenvNoCC.mkDerivation {
        name = "generated-stubs";
        src = bufSrc;
        nativeBuildInputs = [
          pkgs.buf
          bufPlugins
          pkgs.findutils
        ];
        buildPhase = ''
          runHook preBuild
          ${setupBufWorkspace}
          ${runGenerate}
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p "$out/go/api" "$out/python/gen" "$out/rust/api/gen"
          cp -a go/api/. "$out/go/api/"
          cp -a python/gen/. "$out/python/gen/"
          cp -a rust/api/gen/. "$out/rust/api/gen/"
          runHook postInstall
        '';
      };

      # Fail if checked-in stubs differ from hermetic regen.
      generate-check = pkgs.stdenvNoCC.mkDerivation {
        name = "generate-check";
        nativeBuildInputs = [ pkgs.diffutils ];
        buildCommand = ''
          failed=0
          diff_dir() {
            local label="$1" expected="$2" actual="$3"
            if ! diff -ru "$expected" "$actual"; then
              echo "error: $label stubs are out of date. Run 'nix run .#generate' and commit." >&2
              failed=1
            fi
          }
          diff_dir "Go"      "${expectedGo}"      "${generated}/go/api"
          diff_dir "Python"  "${expectedPython}"  "${generated}/python/gen"
          diff_dir "Rust"    "${expectedRust}"    "${generated}/rust/api/gen"
          if [[ "$failed" -ne 0 ]]; then
            exit 1
          fi
          mkdir -p "$out"
          touch "$out/ok"
        '';
      };

      generate-app = pkgs.writeShellApplication {
        name = "generate";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          if [[ ! -f buf.yaml ]]; then
            echo "error: run from the connect-examples repo root (buf.yaml not found)" >&2
            exit 1
          fi
          # Replace trees entirely so renamed/removed stubs disappear from the
          # working copy (cp alone would leave orphans that fail generate-check).
          # Store paths are mode 0555; restore writable perms after install.
          rm -rf go/api python/gen rust/api/gen
          mkdir -p go/api python/gen rust/api/gen
          cp -a --no-preserve=mode ${generated}/go/api/. go/api/
          cp -a --no-preserve=mode ${generated}/python/gen/. python/gen/
          cp -a --no-preserve=mode ${generated}/rust/api/gen/. rust/api/gen/
          chmod -R u+w go/api python/gen rust/api/gen
          echo "installed hermetic stubs from ${generated}"
        '';
        meta.description = "Install hermetic buf-generated stubs into the working tree";
      };
    in
    {
      packages.generated = generated;

      checks = {
        inherit lint-proto generate-check;
      };

      apps = {
        lint-proto = {
          type = "app";
          program = "${appFromCheck "lint-proto" lint-proto}/bin/lint-proto";
          meta.description = "Hermetic buf lint";
        };
        generate = {
          type = "app";
          program = "${generate-app}/bin/generate";
          meta.description = "Install hermetic buf-generated stubs into the working tree";
        };
        generate-check = {
          type = "app";
          program = "${appFromCheck "generate-check" generate-check}/bin/generate-check";
          meta.description = "Fail if checked-in stubs differ from hermetic regen";
        };
      };

      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.buf
          bufPlugins
          go
          rustToolchain
          pkgs.cargo-watch
          pkgs.uv
          python
        ];
      };
    };
}
