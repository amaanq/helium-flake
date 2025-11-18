# helium-flake

A nix flake for [Helium](https://github.com/imputnet/helium-linux), a private, fast, and honest web browser

## Usage

### Run directly

```bash
nix run github:amaanq/helium2nix
```

### Install to profile

```bash
nix profile install github:amaanq/helium2nix
```

### Add to NixOS configuration

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    helium = {
      url = "github:amaanq/helium2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    }
  };

  outputs = inputs: {
    nixosConfigurations.yourhost = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            inputs.helium.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### Build locally

```bash
git clone git@github.com:amaanq/helium-flake.git
cd helium-flake
nix build
./result/bin/helium
```

## Supported Platforms

- x86_64-linux
- aarch64-linux

## Updating

To update to a new Helium release:

1. Check the [latest release](https://github.com/imputnet/helium-linux/releases) and update the version in `flake.nix`:

   ```nix
   version = "0.6.4.1";  # Update this
   ```

2. Fetch the new hashes for both architectures:

   ```bash
   # x86_64
   nix-prefetch-url https://github.com/imputnet/helium-linux/releases/download/0.6.4.1/helium-0.6.4.1-x86_64_linux.tar.xz
   nix hash convert --hash-algo sha256 <hash-from-above>

   # aarch64
   nix-prefetch-url https://github.com/imputnet/helium-linux/releases/download/0.6.4.1/helium-0.6.4.1-arm64_linux.tar.xz
   nix hash convert --hash-algo sha256 <hash-from-above>
   ```

3. Update the `sha256` values in `flake.nix` for both architectures

4. Test the build for both architectures:

   ```bash
   nix build .#packages.x86_64-linux.helium
   ./result/bin/helium --version

   nix build .#packages.aarch64-linux.helium
   ./result/bin/helium --version
   ```

## License

GPL-3.0 (following upstream)
