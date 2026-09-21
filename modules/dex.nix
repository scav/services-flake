{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    services.dex-mock = {
      enable = lib.mkEnableOption "Enable mock Dex OIDC provider";
      package = lib.mkPackageOption pkgs "dex-oidc" { };
      listen = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:8081";
        description = "Host and port for Dex to listen on";
      };
      issuer = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:8082";
        description = "OIDC issuer";
      };
      clientId = lib.mkOption {
        type = lib.types.str;
        default = "mock";
      };
      groups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "NoRole"
          "admin"
        ];
        description = "List of groups allowed to authenticate. If empty, all authenticated users are allowed.";
        example = [
          "admin"
        ];
      };
      staticPasswords = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              email = lib.mkOption {
                type = lib.types.str;
                example = "user@example.com";
                description = "User's email address.";
              };
              password = lib.mkOption {
                type = lib.types.str;
                default = "password";
                description = "Plaintext password.";
              };
              hash = lib.mkOption {
                type = lib.types.str;
                default = "$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W";
                description = "Password password hash.";
              };
              userID = lib.mkOption {
                type = lib.types.str;
                description = "Unique identifier (UUID) for the user.";
              };
              groups = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "unset" ];
                description = "Groups assigned to the user.";
              };
            };
          }
        );
        default = [
          {
            email = "user@example.com";
            password = "password";
            hash = "$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W";
            userID = "083af62d-0e42-4ee4-8f06-fe41a7dc2612";
            groups = [
              "NoRole"
              "admin"
            ];
          }
        ];
        description = "List of users available in Dex built in provider";
        example = [
          {
            email = "user@example.com";
            password = "password";
            hash = "$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W";
            userID = "083af62d-0e42-4ee4-8f06-fe41a7dc2612";
            groups = [
              "NoRole"
              "admin"
            ];
          }
        ];
      };
      staticClients = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              id = lib.mkOption {
                type = lib.types.str;
                example = "public-client";
                description = "Unique client identifier.";
              };
              public = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether the OAuth/OIDC client is a public client.";
              };
              name = lib.mkOption {
                type = lib.types.str;
                example = "Public Client";
                description = "Human-readable client name.";
              };
              redirectURIs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "http://127.0.0.1:3000/oauth2/callback" ];
                example = [
                  "http://127.0.0.1:4180/oauth2/callback"
                  "http://127.0.0.1:3000/oauth2/callback"
                ];
                description = "List of allowed OAuth2 redirect URIs.";
              };
              secret = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Client secret (required for confidential clients).";
              };
            };
          }
        );
        description = "List of clients";
        default = [ ];
      };
    };

  };

  config =
    let
      cfg = config.services.dex-mock;
      dexConfigFile = pkgs.writeText "dex-config.yaml" (
        builtins.toJSON (
          {
            issuer = "http://${cfg.issuer}";
            storage = {
              type = "memory";
            };
            web = {
              http = cfg.listen;
            };
            enablePasswordDB = true;
            staticPasswords = cfg.staticPasswords;
            staticClients = cfg.staticClients;
          }
          // lib.optionalAttrs (cfg.staticClients != [ ]) {
            oauth2 = {
              passwordConnector = "local";
            };
          }
        )
      );
    in
    lib.mkIf cfg.enable {
      settings.processes.dex = {
        command = ''
          ${lib.getExe cfg.package} serve ${dexConfigFile}
        '';
        readiness_probe = {
          exec.command = "curl -f http://${cfg.listen}";
          initial_delay_seconds = 5;
          period_seconds = 5;
        };
      };
    };
}
