# Build one Go cmd package: native + static linux targets (CGO_ENABLED=0).
{
  pkgs,
  buildGoModule,
  goSrc,
  goVendorHash,
}:
{
  pname,
  version,
  # Paths relative to module root, e.g. [ "go/echo/cmd/server" ].
  subPackages,
  # Installed binary name (last path segment of the cmd package by default).
  binName ? builtins.baseNameOf (builtins.head subPackages),
  # Tree path under `result/` / `packages.all` (e.g. "go/echo/server").
  artifactPath,
}:
let
  inherit (pkgs) lib;

  goCommonArgs = {
    inherit
      pname
      version
      subPackages
      ;
    src = goSrc;
    vendorHash = goVendorHash;
    # Workspace tests: nix/test.nix (go-tests).
    doCheck = false;
  };

  native = buildGoModule goCommonArgs;

  mkLinuxPackage =
    {
      goarch,
      goamd64 ? null,
      nameSuffix,
    }:
    buildGoModule (
      goCommonArgs
      // {
        pname = "${pname}-${nameSuffix}";
        env.CGO_ENABLED = "0";
        preBuild = ''
          export CGO_ENABLED=0
          export GOOS=linux
          export GOARCH=${goarch}
          ${lib.optionalString (goamd64 != null) "export GOAMD64=${goamd64}"}
        '';
        postInstall = ''
          if [ -d "$out/bin/linux_${goarch}" ]; then
            mv "$out/bin/linux_${goarch}"/* "$out/bin/"
            rmdir "$out/bin/linux_${goarch}"
          fi
        '';
      }
    );

  x86_64-v1 = mkLinuxPackage {
    goarch = "amd64";
    goamd64 = "v1";
    nameSuffix = "x86-64-v1";
  };

  x86_64-v3 = mkLinuxPackage {
    goarch = "amd64";
    goamd64 = "v3";
    nameSuffix = "x86-64-v3";
  };

  arm64 = mkLinuxPackage {
    goarch = "arm64";
    nameSuffix = "arm64";
  };

  # Artifact layout: <artifactPath>/<variant>/<binName> (no bin/ prefix).
  flattenBin =
    pkg:
    pkgs.runCommand "${pkg.pname}-flat" { } ''
      mkdir -p "$out"
      ln -s "${pkg}/bin/${binName}" "$out/${binName}"
    '';

  packages = {
    ${pname} = native;
    "${pname}-x86_64-v1" = x86_64-v1;
    "${pname}-x86_64-v3" = x86_64-v3;
    "${pname}-arm64" = arm64;
    "${artifactPath}/default" = flattenBin native;
    "${artifactPath}/x86_64-v1-linux" = flattenBin x86_64-v1;
    "${artifactPath}/x86_64-v3-linux" = flattenBin x86_64-v3;
    "${artifactPath}/arm64-linux" = flattenBin arm64;
  };

  apps = {
    ${pname} = {
      type = "app";
      program = "${native}/bin/${binName}";
      meta.description = "Run ${pname}";
    };
  };
in
{
  inherit packages apps;
  checks.${pname} = native;
}
