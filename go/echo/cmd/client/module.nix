# Thin flake-parts module for the Go echo client.
{ ... }:
{
  perSystem =
    {
      pkgs,
      buildGoModule,
      goSrc,
      goVendorHash,
      workspacePackage,
      ...
    }:
    import ../../../../nix/make-go-app.nix {
      inherit
        pkgs
        buildGoModule
        goSrc
        goVendorHash
        ;
    } {
      pname = "go-echo-client";
      version = workspacePackage.version;
      subPackages = [ "go/echo/cmd/client" ];
      artifactPath = "go/echo/client";
    };
}
