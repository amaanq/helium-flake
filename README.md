# helium-flake

A Nix flake for [Helium](https://github.com/imputnet/helium), a private, fast,
and honest web browser

## Usage

### Run directly

```bash
nix run github:amaanq/helium-flake
```

### Install to profile

```bash
nix profile install github:amaanq/helium-flake
```

### Add to NixOS configuration

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    helium = {
      url = "github:amaanq/helium-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, helium, ... }: {
    nixosConfigurations.yourhost = nixpkgs.lib.nixosSystem {
      modules = [
        {
          environment.systemPackages = [
            helium.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### Add to nix-darwin configuration

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium = {
      url = "github:amaanq/helium-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nix-darwin, helium, ... }: {
    darwinConfigurations.yourhost = nix-darwin.lib.darwinSystem {
      modules = [
        {
          environment.systemPackages = [
            helium.packages.aarch64-darwin.default # or x86_64-darwin
          ];
        }
      ];
    };
  };
}
```

## Updating

The version gets automatically updated every 15 minutes via GitHub workflows.

To manually update to the newest release:

1. Update versions: `nix run .#update-versions -- ./versions.json`

2. Test the build: `nix flake check`

3. Commit & Push:
   `git add versions.json && git commit --message "Update versions" && git push`

## License

GPL-3.0 (following upstream)
