# Thin flake-parts module for the rust-echo-client app (Cargo package: echo-client).
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
      pname = "rust-echo-client";
      cargoPackage = "echo-client";
      version = workspacePackage.version;
      artifactPath = "rust/echo/client";
    };
}
