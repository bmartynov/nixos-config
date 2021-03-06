{ pkgs, config, lib, ... }: lib.mkIf (! isNull config.secrets.matrix) {
  services.matrix-synapse = {
    enable = true;
    allow_guest_access = true;
    listeners = [{
      bind_address = "0.0.0.0";
      port = 13748;
      resources = [
        {
          compress = true;
          names = [ "client" ];
        }
        {
          compress = false;
          names = [ "federation" ];
        }
      ];
      type = "http";
      tls = false;
      x_forwarded = true;
    }];
    registration_shared_secret = config.secrets.matrix.shared_secret;
    public_baseurl = "https://balsoft.ru";
    server_name = "balsoft.ru";
    app_service_config_files = [
      (builtins.toFile "registration_tg.yaml"
        (builtins.toJSON config.secrets.matrix.mautrix-telegram.registration))
      (builtins.toFile "registration_wa.yaml"
        (builtins.toJSON config.secrets.matrix.mautrix-whatsapp.registration))
    ];
  };
  services.postgresql.enable = true;
  home-manager.users.balsoft.xsession.windowManager.i3.config.startup = [{
    command = "anbox launch --package=com.whatsapp --component=.HomeActivity";
  }];
  systemd.services.mautrix-whatsapp = {
    description = "A bridge between whatsapp and matrix";
    path = with pkgs; [ coreutils mautrix-whatsapp ];
    wantedBy = [ "multi-user.target" ];
    requires = [
      "matrix-synapse.service"
      "network-online.target"
    ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 1;
    };
    script = ''
      mkdir -p /var/lib/mautrix-whatsapp
      cd /var/lib/mautrix-whatsapp
      sleep 5
      mautrix-whatsapp -c ${
        builtins.toFile "config_wa.yaml"
          (builtins.toJSON config.secrets.matrix.mautrix-whatsapp.config)
      }
    '';
  };

  services.mautrix-telegram = {
    enable = true;
    settings = config.secrets.matrix.mautrix-telegram.config;
  };

  systemd.services.mautrix-telegram.serviceConfig.DynamicUser = lib.mkForce false;

  users.users.matrix-synapse.name = lib.mkForce "matrix-synapse";
}
