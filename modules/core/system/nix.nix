{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
with lib; let
  filterNixFiles = k: v: v == "regular" && hasSuffix ".nix" k;
  importNixFiles = path:
    (lists.forEach (mapAttrsToList (name: _: path + ("/" + name))
        (filterAttrs filterNixFiles (builtins.readDir path))))
    import;
in {
  system = {
    autoUpgrade.enable = false;
    stateVersion = lib.mkDefault "23.05";
  };
  environment = {
    # set channels (backwards compatibility)
    etc = {
      #"nix/flake-channels/system".source = inputs.self; # no worky
      "nix/flake-channels/nixpkgs".source = inputs.nixpkgs;
      "nix/flake-channels/home-manager".source = inputs.home-manager;
    };

    # we need git for flakes, don't we
    systemPackages = [pkgs.git];
    defaultPackages = [];
  };

  nixpkgs = {
    config = {
      allowUnfree = true; # really a pain in the ass to deal with when disabled
      allowBroken = true;
      allowUnsupportedSystem = true;
    };

    overlays = with inputs;
      [
        (
          final: _: let
            inherit (final) system;
          in (with nixpkgs-f2k.packages.${system}; {
            # Overlays with f2k's repo
            wezterm = wezterm-git;
          })
        )
        nur.overlay
        nixpkgs-f2k.overlays.default
        rust-overlay.overlays.default
      ]
      # Overlays from ./overlays directory
      ++ (importNixFiles ../../overlays);
  };

  # faster rebuilding
  documentation = {
    enable = true;
    doc.enable = false;
    man.enable = true;
    dev.enable = false;
  };

  nix = {
    package = pkgs.nixUnstable;

    gc = {
      # set up garbage collection to run daily,
      # removing unused packages after three days
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 3d";
    };

    # pin the registry to avoid downloading and evalıationg a new nixpkgs
    # version everytime
    registry = lib.mapAttrs (_: v: {flake = v;}) inputs;

    # set the path for channels compat
    nixPath = [
      "nixpkgs=/etc/nix/flake-channels/nixpkgs"
      "home-manager=/etc/nix/flake-channels/home-manager"
    ];

    # Free up to 1GiB whenever there is less than 100MiB left.
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      min-free = ${toString (100 * 1024 * 1024)}
      max-free = ${toString (1024 * 1024 * 1024)}
      accept-flake-config = true
      http-connections = 0
      warn-dirty = false
    '';
    settings = {
      auto-optimise-store = true;
      # allow sudo users to mark the following values as trusted
      allowed-users = ["@wheel" "notashelf"];
      # only allow sudo users to manage the nix store
      trusted-users = ["@wheel" "notashelf"];
      max-jobs = "auto";
      sandbox = true;
      system-features = ["kvm" "recursive-nix" "big-parallel"];
      # continue building derivations if one fails
      keep-going = true;
      # show more log lines for failed builds
      log-lines = 20;
      # enable new nix command and flakes
      # and also "unintended" recursion
      extra-experimental-features = [
        "flakes"
        "nix-command"
        "recursive-nix"
      ];

      # use binary cache, its not gentoo
      builders-use-substitutes = true;
      substituters = [
        "https://cache.nixos.org"
        "https://fortuneteller2k.cachix.org"
        "https://nixpkgs-wayland.cachix.org"
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
        "https://nix-gaming.cachix.org"
        "https://nixpkgs-unfree.cachix.org"
        "https://webcord.cachix.org"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "fortuneteller2k.cachix.org-1:kXXNkMV5yheEQwT0I4XYh1MaCSz+qg72k8XAi2PthJI="
        "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
        "webcord.cachix.org-1:l555jqOZGHd2C9+vS8ccdh8FhqnGe8L78QrHNn+EFEs="
      ];
    };
  };
}