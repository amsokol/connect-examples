# Thin flake-parts module for the Go echo server.
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
      pname = "go-echo-server";
      version = workspacePackage.version;
      subPackages = [ "go/echo/cmd/server" ];
      artifactPath = "go/echo/server";
    };
}
