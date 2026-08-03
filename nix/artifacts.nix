# Aggregate release trees under result/{rust,go,python}/echo/…
# packages.default / packages.all are hermetic linkFarms of app derivations.
# apps.rebuild only orchestrates `nix build --rebuild` (builds stay sandboxed).
{ lib, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      linuxVariants = [
        "default"
        "x86_64-v1-linux"
        "x86_64-v3-linux"
        "arm64-linux"
      ];

      # Per-app artifact variants. Python is host-only (no GOAMD64-style splits).
      apps = [
        {
          path = "rust/echo/server";
          variants = linuxVariants;
          leaf = "rust-echo-server";
          variantLeaves = [
            "rust-echo-server-x86_64-v1"
            "rust-echo-server-x86_64-v3"
            "rust-echo-server-arm64"
          ];
        }
        {
          path = "rust/echo/client";
          variants = linuxVariants;
          leaf = "rust-echo-client";
          variantLeaves = [
            "rust-echo-client-x86_64-v1"
            "rust-echo-client-x86_64-v3"
            "rust-echo-client-arm64"
          ];
        }
        {
          path = "go/echo/server";
          variants = linuxVariants;
          leaf = "go-echo-server";
          variantLeaves = [
            "go-echo-server-x86_64-v1"
            "go-echo-server-x86_64-v3"
            "go-echo-server-arm64"
          ];
        }
        {
          path = "go/echo/client";
          variants = linuxVariants;
          leaf = "go-echo-client";
          variantLeaves = [
            "go-echo-client-x86_64-v1"
            "go-echo-client-x86_64-v3"
            "go-echo-client-arm64"
          ];
        }
        {
          path = "python/echo/client";
          variants = [ "default" ];
          leaf = "python-echo-client";
          variantLeaves = [ ];
        }
      ];

      linkEntries =
        paths:
        pkgs.linkFarm "artifacts" (
          map (path: {
            name = path;
            path = config.packages.${path};
          }) paths
        );

      hostEntries = map (app: "${app.path}/default") apps;
      allEntries = lib.concatMap (app: map (v: "${app.path}/${v}") app.variants) apps;

      hostLeaves = map (app: app.leaf) apps;
      allLeaves = hostLeaves ++ lib.concatMap (app: app.variantLeaves) apps;

      toFlakeRefs = lib.concatMapStringsSep " " (p: ".#${lib.escapeShellArg p}");

      rebuild = pkgs.writeShellApplication {
        name = "rebuild";
        runtimeInputs = [
          pkgs.nix
          pkgs.coreutils
        ];
        text = ''
          if [[ ! -f flake.nix ]]; then
            echo "error: run from the connect-examples repo root (flake.nix not found)" >&2
            exit 1
          fi

          target="''${1:-default}"
          case "$target" in
            default)
              leaves=(${toFlakeRefs hostLeaves})
              aggregate=.#default
              ;;
            all)
              leaves=(${toFlakeRefs allLeaves})
              aggregate=.#all
              ;;
            *)
              echo "usage: nix run .#rebuild [default|all]" >&2
              exit 1
              ;;
          esac

          shopt -s nullglob
          for path in result result-*; do
            rm -rf -- "$path"
            echo "removed out-link $path"
          done

          # --rebuild fails if the output was never built; fall back to a fresh build.
          force_build() {
            local -a link_args=()
            while [[ $# -gt 0 ]]; do
              case "$1" in
                --no-link)
                  link_args+=(--no-link)
                  shift
                  ;;
                --out-link)
                  link_args+=(--out-link "$2")
                  shift 2
                  ;;
                *)
                  break
                  ;;
              esac
            done

            local -a existing=()
            local -a missing=()
            local pkg
            for pkg in "$@"; do
              if nix path-info "$pkg" >/dev/null 2>&1; then
                existing+=("$pkg")
              else
                missing+=("$pkg")
              fi
            done

            if ((''${#existing[@]} > 0)); then
              nix build --rebuild "''${link_args[@]}" "''${existing[@]}" \
                || nix build "''${link_args[@]}" "''${existing[@]}"
            fi
            if ((''${#missing[@]} > 0)); then
              if ((''${#existing[@]} > 0)); then
                nix build --no-link "''${missing[@]}"
              else
                nix build "''${link_args[@]}" "''${missing[@]}"
              fi
            fi
          }

          force_build --no-link "''${leaves[@]}"
          force_build --out-link result "$aggregate"
        '';
      };
    in
    {
      packages.default = linkEntries hostEntries;
      packages.all = linkEntries allEntries;

      apps.rebuild = {
        type = "app";
        program = "${rebuild}/bin/rebuild";
        meta.description = "Force-rebuild host (.#default) or all artifact variants";
      };
    };
}
