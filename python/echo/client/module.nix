# Thin flake-parts module for the Python echo client.
{ ... }:
{
  perSystem =
    {
      pkgs,
      pythonSet,
      pythonWorkspace,
      pythonProjectVersion,
      ...
    }:
    import ../../../nix/make-python-app.nix {
      inherit
        pkgs
        pythonSet
        pythonWorkspace
        ;
    } {
      pname = "python-echo-client";
      version = pythonProjectVersion;
      module = "python.echo.client";
      artifactPath = "python/echo/client";
    };
}
