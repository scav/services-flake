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
      clientId = lib.mkOption {
        type = lib.types.str;
        default = "mock";
      };
      redirectURIs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "http://127.0.0.1:4180/oauth2/callback"
          "http://127.0.0.1:3000/oauth2/callback"
        ];
        description = "Where Dex should redirect back to after login";
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
    };
  };

  config =
    let
      cfg = config.services.dex-mock;

      dexConfigFile = pkgs.writeText "dex-config.yaml" (
        builtins.toJSON {
          issuer = "http://${cfg.listen}";
          storage = {
            type = "memory";
          };
          web = {
            http = cfg.listen;
          };
          staticClients = [
            {
              id = cfg.clientId;
              name = "Mock Client Proxy";
              secret = "proxy";
              redirectURIs = cfg.redirectURIs;
            }
          ];
          enablePasswordDB = true;
          staticPasswords = [
            {
              email = "user@example.com";
              password = "password";
              hash = "$2a$10$2b2cU8CPhOTaGrs1HRQuAueS7JTT5ZHsHSzYiFPm1leZck7Mc8T4W";
              userID = "083af62d-0e42-4ee4-8f06-fe41a7dc2612";
              groups = cfg.groups;
            }
          ];
        }
      );
    in
    lib.mkIf cfg.enable {
      settings.processes.dex = {
        command = ''
          ${lib.getExe cfg.package} serve ${dexConfigFile}
        '';
        readiness_probe = {
          exec.command = "curl -f http://127.0.0.1:8081";
          initial_delay_seconds = 5;
          period_seconds = 5;
        };
      };
    };
}
