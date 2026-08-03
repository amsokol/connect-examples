# Local buf codegen plugins (pins from tools.version.toml).
{ ... }:
{
  perSystem =
    {
      pkgs,
      versions,
      python,
      ...
    }:
    let
      inherit (pkgs) fetchCrate fetchurl;
      inherit (pkgs) rustPlatform;
      py = python.pkgs;

      # Go plugins: overlaid in toolchains.nix from tools.version.toml.
      inherit (pkgs) protoc-gen-go protoc-gen-connect-go;

      # --- Python (each plugin gets its own env; deps versions differ) ---
      # protobuf-py declares protobuf-py-ext; codegen plugins typically only need
      # the pure-Python CodeGeneratorRequest path, so skip the runtime-dep check.
      mkPyWheel =
        pin: pname:
        py.buildPythonPackage {
          inherit pname;
          version = pin.version;
          format = "wheel";
          src = fetchurl {
            url = pin.url;
            hash = pin.hash;
          };
          dontCheckRuntimeDeps = true;
          doCheck = false;
        };

      mkPyApp =
        pin: pname: deps:
        py.buildPythonApplication {
          inherit pname;
          version = pin.version;
          format = "wheel";
          src = fetchurl {
            url = pin.url;
            hash = pin.hash;
          };
          propagatedBuildInputs = deps;
          dontCheckRuntimeDeps = true;
          doCheck = false;
        };

      protobuf-py = mkPyWheel versions."protobuf-py" "protobuf-py";
      protobuf-py-for-connectrpc = mkPyWheel versions."protobuf-py-for-connectrpc" "protobuf-py";

      protoc-gen-py = mkPyApp versions."protoc-gen-py" "protoc-gen-py" [ protobuf-py ];
      protoc-gen-connectrpc = mkPyApp versions."protoc-gen-connectrpc" "protoc-gen-connectrpc" [
        protobuf-py-for-connectrpc
      ];

      # --- Rust ---
      buffaPin = versions."protoc-gen-buffa";
      protoc-gen-buffa = rustPlatform.buildRustPackage {
        pname = "protoc-gen-buffa";
        version = buffaPin.version;
        src = fetchCrate {
          pname = "protoc-gen-buffa";
          version = buffaPin.version;
          hash = buffaPin.hash;
        };
        cargoHash = buffaPin.cargoHash;
        doCheck = false;
      };

      connectRustPin = versions."protoc-gen-connect-rust";
      protoc-gen-connect-rust = rustPlatform.buildRustPackage {
        pname = "protoc-gen-connect-rust";
        version = connectRustPin.version;
        src = fetchCrate {
          pname = connectRustPin.crate;
          version = connectRustPin.version;
          hash = connectRustPin.hash;
        };
        cargoHash = connectRustPin.cargoHash;
        doCheck = false;
      };

      bufPlugins = pkgs.symlinkJoin {
        name = "buf-plugins";
        paths = [
          protoc-gen-go
          protoc-gen-connect-go
          protoc-gen-py
          protoc-gen-connectrpc
          protoc-gen-buffa
          protoc-gen-connect-rust
        ];
      };
    in
    {
      _module.args = {
        inherit bufPlugins;
      };

      packages = {
        inherit
          bufPlugins
          protoc-gen-go
          protoc-gen-connect-go
          protoc-gen-py
          protoc-gen-connectrpc
          protoc-gen-buffa
          protoc-gen-connect-rust
          ;
      };
    };
}
