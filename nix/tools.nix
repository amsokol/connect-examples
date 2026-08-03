# CLI tools packaged for `nix run` / `nix build` (pins from tools.version.toml via toolchains overlay).
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        inherit (pkgs)
          grpc-health-probe
          golangci-lint
          govulncheck
          cargo-audit
          pip-audit
          ruff
          markdownlint-cli2
          ;
      };

      apps.grpc-health-probe = {
        type = "app";
        program = "${pkgs.grpc-health-probe}/bin/grpc-health-probe";
        meta.description = "gRPC health-check probe CLI";
      };
    };
}
