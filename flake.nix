{
  description = "connect-examples: Nix tooling (buf + Go/Python/Rust apps)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    # Pinned RustSec advisory DB for hermetic `nix run .#vuln-rust` / cargo audit.
    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      imports = [
        ./nix/toolchains.nix
        ./nix/buf-plugins.nix
        ./nix/buf.nix
        ./nix/lint.nix
        ./nix/vuln.nix
        ./nix/tools.nix
        ./nix/artifacts.nix
        ./nix/test.nix
        ./rust/echo/server/module.nix
        ./rust/echo/client/module.nix
        ./go/echo/cmd/server/module.nix
        ./go/echo/cmd/client/module.nix
        ./python/echo/client/module.nix
      ];
    };
}
