# service flakes

A simple collection of service configurations for services not currently available [services-flake](https://community.flake.parts/services-flake/services).

## Services
These are the services available, note that they do not support all available config options.
- Dex
- Oauth2 Proxy

## How to use
A simple example on how to use these services. If you want to use official services as well, make sure to add services-flake
to the list of inputs as well and import the modules like we did with extra-services here.
```nix
{
  description = "example project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    extra-services.url = "github:scav/services-flake";
  };

  outputs =
    {
      nixpkgs,
      process-compose-flake,
      extra-services,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          services = (import process-compose-flake.lib { inherit pkgs; }).evalModules {
            modules = [
              extra-services.processComposeModules.default
              {
                services.oauth2-proxy = {
                  enable = true;
                  dex = true;
                  upstreamURL = "http://127.0.0.1:3000";
                };
                services.dex-mock.enable = true;
              }
              {
                # Leave process-compose open on errors
                cli.options.keep-project = true;
              }
            ];
          };

        in
        {
          services = services.config.outputs.package;
        }
      );
    };
}
```


