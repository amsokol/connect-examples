# Build one workspace crate: native + static musl linux targets.
{
  pkgs,
  craneLib,
  rustSrc,
  cargoVendorDir,
}:
{
  pname,
  version,
  # Cargo workspace package / binary name (`cargo build -p …`). Defaults to pname.
  cargoPackage ? pname,
  # Tree path under `result/` / `packages.all` (e.g. "rust/echo/server").
  artifactPath,
}:
let
  inherit (pkgs) lib;

  rustCommonArgs = {
    src = rustSrc;
    inherit cargoVendorDir;
    strictDeps = true;
    inherit pname version;
    cargoExtraArgs = "-p ${cargoPackage}";
    # Workspace tests: nix/test.nix (rust-tests).
    doCheck = false;
  };

  native =
    let
      cargoArtifacts = craneLib.buildDepsOnly rustCommonArgs;
    in
    craneLib.buildPackage (
      rustCommonArgs
      // {
        inherit cargoArtifacts;
      }
    );

  mkMuslPackage =
    {
      rustTarget,
      pkgsCross,
      targetCpu ? null,
      pnameSuffix,
    }:
    let
      linker = "${pkgsCross.stdenv.cc}/bin/${pkgsCross.stdenv.cc.targetPrefix}cc";
      linkerEnvName =
        "CARGO_TARGET_${
          lib.toUpper (builtins.replaceStrings [ "-" ] [ "_" ] rustTarget)
        }_LINKER";
      # `cc` crate / build.rs must use the musl toolchain (not host glibc).
      ccEnvName = "CC_${builtins.replaceStrings [ "-" ] [ "_" ] rustTarget}";

      rustflags =
        "-C target-feature=+crt-static"
        + lib.optionalString (targetCpu != null) " -C target-cpu=${targetCpu}";

      targetArgs = rustCommonArgs // {
        pname = "${pname}-${pnameSuffix}";
        CARGO_BUILD_TARGET = rustTarget;
        CARGO_BUILD_RUSTFLAGS = rustflags;
        "${linkerEnvName}" = linker;
        "${ccEnvName}" = linker;
        TARGET_CC = linker;
        HOST_CC = "${pkgs.stdenv.cc}/bin/cc";
        depsBuildBuild = [ pkgs.stdenv.cc ];
        nativeBuildInputs = [ pkgsCross.stdenv.cc ];
        # fortify + musl often breaks C deps (e.g. allocator crates); not a hardening upgrade.
        hardeningDisable = [ "fortify" ];
        NIX_CFLAGS_COMPILE = "-U_FORTIFY_SOURCE";
        doCheck = false;
      };

      cargoArtifacts = craneLib.buildDepsOnly targetArgs;
    in
    craneLib.buildPackage (
      targetArgs
      // {
        inherit cargoArtifacts;
      }
    );

  x86_64-v1 = mkMuslPackage {
    rustTarget = "x86_64-unknown-linux-musl";
    pkgsCross = pkgs.pkgsCross.musl64;
    targetCpu = "x86-64";
    pnameSuffix = "x86-64-v1";
  };

  x86_64-v3 = mkMuslPackage {
    rustTarget = "x86_64-unknown-linux-musl";
    pkgsCross = pkgs.pkgsCross.musl64;
    targetCpu = "x86-64-v3";
    pnameSuffix = "x86-64-v3";
  };

  arm64 = mkMuslPackage {
    rustTarget = "aarch64-unknown-linux-musl";
    pkgsCross = pkgs.pkgsCross.aarch64-multiplatform-musl;
    pnameSuffix = "arm64";
  };

  # Artifact layout: <artifactPath>/<variant>/<cargoPackage> (no bin/ prefix).
  flattenBin =
    pkg:
    pkgs.runCommand "${pkg.pname}-flat" { } ''
      mkdir -p "$out"
      ln -s "${pkg}/bin/${cargoPackage}" "$out/${cargoPackage}"
    '';

  packages = {
    ${pname} = native;
    "${pname}-x86_64-v1" = x86_64-v1;
    "${pname}-x86_64-v3" = x86_64-v3;
    "${pname}-arm64" = arm64;
    # Source-mirrored paths under packages.all / result/
    "${artifactPath}/default" = flattenBin native;
    "${artifactPath}/x86_64-v1-linux" = flattenBin x86_64-v1;
    "${artifactPath}/x86_64-v3-linux" = flattenBin x86_64-v3;
    "${artifactPath}/arm64-linux" = flattenBin arm64;
  };

  apps = {
    ${pname} = {
      type = "app";
      program = "${native}/bin/${cargoPackage}";
      meta.description = "Run ${pname}";
    };
  };
in
{
  inherit packages apps;
  checks.${pname} = native;
}
