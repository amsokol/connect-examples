# Thin flake-parts module for the rust-echo-server app (Cargo package: echo-server).
{ ... }:
{
  perSystem =
    {
      pkgs,
      craneLib,
      rustSrc,
      cargoVendorDir,
      workspacePackage,
      ...
    }:
    import ../../../nix/make-rust-app.nix {
      inherit
        pkgs
        craneLib
        rustSrc
        cargoVendorDir
        ;
    } {
      pname = "rust-echo-server";
      cargoPackage = "echo-server";
      version = workspacePackage.version;
      artifactPath = "rust/echo/server";
    };
}
