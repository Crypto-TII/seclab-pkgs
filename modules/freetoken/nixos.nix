# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 Brian McGillion
# FreeToken edge-native MoE serving engine
#
# Installs the FHS-wrapped `ft` CLI from packages/misc/freetoken. See that file
# for why FreeToken is sandboxed rather than packaged natively.
#
# REQUIRES overlays.default on the consumer's pkgs -- that is where
# pkgs.freetoken comes from. The assertion below turns a missing overlay into
# an evaluation error with a message rather than a bare "attribute 'freetoken'
# missing" later on.
#
# Usage:
#   features.ai.freetoken.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.features.ai.freetoken;
in
{
  options.features.ai.freetoken = {
    enable = lib.mkEnableOption "FreeToken edge-native MoE serving engine (FHS-wrapped)";

    package = lib.mkPackageOption pkgs "freetoken" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 1919;
      description = ''
        Port `ft serve` listens on. Only used to derive the firewall rule below;
        the server itself still takes --port.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open {option}`features.ai.freetoken.port` to the local network. Off by
        default: the API is unauthenticated, so exposing it is a deliberate act.
      '';
    };

    home = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/data/freetoken";
      description = ''
        Value for $FREETOKEN_HOME, holding the venv and the kernel cache. Set it
        when the default (~/.freetoken) lands on a disk too small for a
        multi-GB torch/CUDA venv.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      # Implication rather than a bare check: a consumer who imports this
      # module but never enables FreeToken has no reason to need the overlay.
      {
        assertion = cfg.enable -> (pkgs ? freetoken);
        message = ''
          features.ai.freetoken.enable is on but pkgs.freetoken is missing.
          Add seclab-pkgs' overlays.default to nixpkgs.overlays on this host.
        '';
      }
      {
        assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
        message = ''
          features.ai.freetoken is x86_64-linux only: FreeToken publishes no
          other wheels, and its CUDA 13 kernels are built for that platform.
        '';
      }
      # FreeToken is NVIDIA-only (driver r580+). Detect the driver via
      # videoDrivers, which is only populated once an nvidia module is imported.
      {
        assertion = lib.elem "nvidia" (config.services.xserver.videoDrivers or [ ]);
        message = ''
          features.ai.freetoken requires an NVIDIA GPU: FreeToken has no
          CPU-only or ROCm path, and its CUDA 13 kernels need the proprietary
          driver. Enable the nvidia driver on this host, or disable the feature.
        '';
      }
    ];

    environment.systemPackages = [ cfg.package ];

    environment.sessionVariables = lib.mkIf (cfg.home != null) {
      FREETOKEN_HOME = cfg.home;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
