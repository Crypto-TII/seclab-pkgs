# SPDX-FileCopyrightText: 2025-2026 Technology Innovation Institute (TII)
# SPDX-License-Identifier: Apache-2.0
#
# Two unrelated nixpkgs breakages in semgrep 1.180.0, both scoped to it.
#
# patchelf aborts on semgrep-core's prebuilt OCaml binary -- `Assertion
# `splitIndex == -1' failed` in shiftFile -- which fails the only patchelf call
# semgrep-core makes. nixpkgs#579107; hydra reproduces it.
#
# 0.15.2 was nixpkgs' patchelf until the 0.19.2 bump landed beside semgrep
# 1.180.0, so this is the combination that worked before, not a new one. 0.18
# and 0.19.2 both abort. Scoped to the one patchelf call semgrep-core makes;
# nothing else here is built with it. Drop once the abort is fixed upstream.
_final: prev:
let
  patchelf_0_15 = prev.patchelf.overrideAttrs (_: {
    version = "0.15.2";
    src = prev.fetchurl {
      url = "https://github.com/NixOS/patchelf/releases/download/0.15.2/patchelf-0.15.2.tar.bz2";
      hash = "sha256-F3RfVkFZyOIo/EEtplogSLhGxLa0Igt3y/IkFuAvLXw=";
    };
    doCheck = false; # 0.15.2's suite predates the sandbox fixes 0.19 carries
  });
in
{
  # Only `semgrep`: python-packages.nix passes semgrep-core as an inline
  # callPackage argument rather than a set member, so `.override` is the one way
  # in, and all-packages re-exports top-level semgrep-core from this passthru --
  # so it follows along instead of needing its own override, which would recurse.
  semgrep =
    (prev.semgrep.override {
      semgrep-core = prev.python3Packages.semgrep.semgrep-core.override {
        patchelf = patchelf_0_15;
      };

      # semgrep pins `mcp==1.29.0` and uses mcp.server.fastmcp, which 2.x replaced
      # with an MCPServer whose constructor rejects four of the kwargs semgrep
      # passes; nixpkgs lists "mcp" in pythonRelaxDeps, so the pin that would have
      # caught this is stripped and the build fails importing mcp.server.fastmcp.
      # mcp_1 is nixpkgs' own 1.29.0 compat attribute, kept for exactly this and
      # just not wired up here. Drop once semgrep migrates to the 2.x API.
      mcp = prev.python3Packages.mcp_1;
    })
    # The wrapper resolves deps with site.addsitedir, which appends, so anything
    # already on PYTHONPATH wins. toolsets/python.nix puts mcp 2.x there, which
    # then shadows the 1.29.0 above and breaks `semgrep mcp` inside the devshell.
    # The wrapper sets PYTHONNOUSERSITE, so it already means to be isolated.
    .overridePythonAttrs
      (old: {
        makeWrapperArgs = (old.makeWrapperArgs or [ ]) ++ [
          "--unset"
          "PYTHONPATH"
        ];
      });
}
