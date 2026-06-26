{
  config,
  lib,
  pkgs,
  ...
}:
{
  options = {
    services.oauth2-proxy = {
      enable = lib.mkEnableOption "Enable oauth2-proxy";
      dex = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "If using Dex wait for it to be ready.";
      };
      package = lib.mkPackageOption pkgs "oauth2-proxy" { };
      listen = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:4180";
        description = "Host and port to bind to";
      };
      issuerUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:8081";
        description = "OpenID Connect issuer (dex)";
      };
      clientId = lib.mkOption {
        type = lib.types.str;
        default = "mock";
      };
      cookieSecret = lib.mkOption {
        type = lib.types.str;
        default = "xWzF2JYyYxQ7iGNKHDVlm_mSUe0sCfFs_bbjJa_xZQM=";
      };
      passAccessToken = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      redirectURL = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:4180/oauth2/callback";
        description = "Redirect to application";
      };
      upstreamURL = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:3000";
      };
      headers = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Header name (e.g. X-Auth-Request-User)";
              };
              claim = lib.mkOption {
                type = lib.types.str;
                description = "Session claim to source the value from (e.g. user, email, groups, preferred_username)";
              };
            };
          }
        );
        default = [
          {
            name = "X-Auth-Request-User";
            claim = "user";
          }
          {
            name = "X-Auth-Request-Email";
            claim = "email";
          }
          {
            name = "X-Auth-Request-Groups";
            claim = "groups";
          }
          {
            name = "X-Auth-Request-Preferred-Username";
            claim = "preferred_username";
          }
        ];
        description = "Headers to inject into upstream requests and auth response";
      };
    };
  };
  config =
    let
      cfg = config.services.oauth2-proxy;

      toHeader = h: {
        name = h.name;
        values = [
          {
            claimSource = {
              claim = h.claim;
            };
          }
        ];
      };

      cfgFile = pkgs.writeText "config.yaml" (
        builtins.toJSON {
          server = {
            bindAddress = cfg.listen;
          };
          providers = [
            {
              id = "proxy";
              name = "mockedid-connect OIDC";
              provider = "oidc";
              clientID = cfg.clientId;
              clientSecret = "proxy";
              scope = "openid email profile groups";
              oidcConfig = {
                insecureAllowUnverifiedEmail = true;
                issuerURL = cfg.issuerUrl;
              };
            }
          ];
          upstreamConfig = {
            upstreams = [
              {
                id = "default";
                path = "/";
                uri = cfg.upstreamURL;
              }
            ];
          };
          injectRequestHeaders = map toHeader cfg.headers;
          injectResponseHeaders = map toHeader cfg.headers;
        }
      );
    in
    lib.mkIf cfg.enable {
      settings.processes.oauth2-proxy = lib.mkMerge [
        (lib.mkIf cfg.dex {
          depends_on = {
            dex = {
              condition = "process_healthy";
            };
          };
        })
        {
          command = ''
            ${lib.getExe cfg.package} \
              --alpha-config ${cfgFile} \
              --redirect-url ${cfg.redirectURL} \
              --email-domain example.com \
              --cookie-secure false \
              --cookie-secret ${cfg.cookieSecret} \
              --show-debug-on-error \
              --skip-jwt-bearer-tokens
          '';
        }
      ];
    };
}
