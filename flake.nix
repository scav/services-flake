{
  description = "Extra services for services-flake";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = { ... }: {
    processComposeModules =
      let
        individualModules = {
          dex = ./modules/dex.nix;
          oauth2-proxy = ./modules/oauth2-proxy.nix;
        };
      in
      individualModules
      // {
        default = {
          imports = builtins.attrValues individualModules;
        };
      };
  };
}
