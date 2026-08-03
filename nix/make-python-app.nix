# Build one Python module entrypoint: host-only (no GOAMD64-style linux variants).
{
  pkgs,
  pythonSet,
  pythonWorkspace,
  ...
}:
{
  pname,
  version,
  # Dotted module path for `python -m`, e.g. "python.echo.client".
  module,
  # Name of the editable/wheel package in the uv workspace (pyproject [project].name).
  projectName ? "connect-examples",
  # Tree path under `result/` / packages (e.g. "python/echo/client").
  artifactPath,
}:
let
  venv = pythonSet.mkVirtualEnv "${pname}-env" pythonWorkspace.deps.default;

  # Wrap `python -m` from the locked venv under a stable CLI name.
  native = pkgs.stdenv.mkDerivation {
    inherit pname version;
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      makeWrapper "${venv}/bin/python" "$out/bin/${pname}" \
        --add-flags "-m ${module}"
      runHook postInstall
    '';
    # Expose the venv for smoke tests / vuln scanning helpers.
    passthru = {
      inherit venv;
      project = pythonSet.${projectName};
    };
    meta = {
      mainProgram = pname;
      description = "Run ${pname} (${module})";
    };
  };

  # Artifact layout: <artifactPath>/default/<pname> (no bin/ prefix).
  flattenBin = pkgs.runCommand "${pname}-flat" { } ''
    mkdir -p "$out"
    ln -s "${native}/bin/${pname}" "$out/${pname}"
  '';

  packages = {
    ${pname} = native;
    "${artifactPath}/default" = flattenBin;
  };

  apps = {
    ${pname} = {
      type = "app";
      program = "${native}/bin/${pname}";
      meta.description = "Run ${pname} (${module})";
    };
  };
in
{
  inherit packages apps;
  checks.${pname} = native;
}
