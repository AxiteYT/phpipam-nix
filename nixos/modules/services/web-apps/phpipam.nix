{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.phpipam;
  inherit (lib.options) showOption showFiles;
in
{
  meta = with lib; {
    description = "phpIPAM web application";
    license = licenses.gpl3;
    homepage = "https://phpipam.net/";
    maintainers = with maintainers; [ AxiteYT ];
  };

  options = {
    services.phpipam = {
      enable = mkEnableOption "phpipam";
      package = mkPackageOption pkgs "phpipam" { };
      port = mkOption {
        type = with types; attrsOf int;
        default = if cfg.enableSSl then 443 else 80;
        description = "Port to listen on";
      };
    };
    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to open the firewall for Glance.
        This adds `services.phpipam.port` to `networking.firewall.allowedTCPPorts`.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = mkIf cfg.openFirewall { allowedTCPPorts = [ cfg.port ]; };
  };
}
