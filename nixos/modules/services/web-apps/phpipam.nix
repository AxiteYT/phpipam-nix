{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.phpipam;
in
{
  options = {
    services.phpipam = {
      enable = mkEnableOption "phpIPAM web application";

      package = mkOption {
        type = types.package;
        default = pkgs.phpipam;
        description = "phpIPAM package to use.";
      };

      port = mkOption {
        type = types.int;
        default = if cfg.enableSSL then 443 else 80;
        description = "Port on which phpIPAM will listen.";
      };

      enableSSL = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable SSL for phpIPAM.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to open the firewall for phpIPAM.
          This adds `services.phpipam.port` to `networking.firewall.allowedTCPPorts`.
        '';
      };

      hostName = mkOption {
        type = types.str;
        default = "phpipam.local";
        description = "Hostname for the phpIPAM web interface.";
      };

      user = mkOption {
        type = types.str;
        default = "nginx";
        description = ''
          User account under which the web application runs.
        '';
      };

      group = mkOption {
        type = types.str;
        default = "nginx";
        description = ''
          Group under which the web application runs.
        '';
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/phpipam";
        description = ''
          Directory where phpIPAM stores persistent data.
        '';
      };

      database = mkOption {
        type = types.attrs;
        default = {
          enable = false;
          host = "localhost";
          user = "phpipam";
          password = "secret";
          name = "phpipam_db";
        };
        description = "Database configuration for phpIPAM.";
        options = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to manage the database with NixOS.";
          };
          host = mkOption {
            type = types.str;
            default = "localhost";
            description = "Database host.";
          };
          user = mkOption {
            type = types.str;
            default = "phpipam";
            description = "Database user.";
          };
          password = mkOption {
            type = types.str;
            default = "secret";
            description = "Database password.";
          };
          name = mkOption {
            type = types.str;
            default = "phpipam_db";
            description = "Database name.";
          };
        };
      };

      config = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = ''
          Additional configuration options for phpIPAM.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.phpfpm.pools.phpipam = {
      user = cfg.user;
      group = cfg.group;
      phpPackage = pkgs.php81;
      settings = {
        "listen.owner" = cfg.user;
        "listen.group" = cfg.group;
        "listen.mode" = "0660";
        "pm" = "dynamic";
        "pm.max_children" = 10;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 2;
        "pm.max_spare_servers" = 5;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/uploads 0750 ${cfg.user} ${cfg.group} -"
    ];

    services.nginx = mkIf (cfg.hostName != null) {
      enable = true;
      virtualHosts."${cfg.hostName}" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
            ssl = cfg.enableSSL;
          }
        ];
        root = "${cfg.package}/share/phpipam";
        index = "index.php";
        extraConfig = ''
          location / {
            try_files $uri $uri/ /index.php$is_args$args;
          }

          location ~ \.php$ {
            include ${config.services.nginx.package}/conf/fastcgi_params;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:${config.services.phpfpm.pools.phpipam.socket};
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          }
        '';
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    # Database Initialization
    services.mysql = mkIf cfg.database.enable {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          password = cfg.database.password;
          privileges = {
            "${cfg.database.name}.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    # Generate config.php
    environment.etc."phpipam/config.php".text = ''
      <?php
      // Database connection details
      $db['host'] = '${cfg.database.host}';
      $db['user'] = '${cfg.database.user}';
      $db['pass'] = '${cfg.database.password}';
      $db['name'] = '${cfg.database.name}';
      $db['port'] = 3306;
      $db['webhost'] = '${lib.mkIf cfg.enableSSL "https://" "http://"}${cfg.hostName}';
      // Additional configuration
      ${concatStringsSep "\n" (
        map (key: ''
          $config['${key}'] = '${cfg.config.${key}}';
        '') (attrNames cfg.config)
      )}
    '';
  };

  meta = with lib; {
    description = "phpIPAM web application";
    license = licenses.gpl3Only;
    homepage = "https://phpipam.net/";
    maintainers = with maintainers; [ AxiteYT ];
  };
}
