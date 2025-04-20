inputs:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.asus-numberpad-driver;

  ini = pkgs.formats.ini { };

  # Writable directory for the config file
  configDir = "/etc/asus-numberpad-driver/";
in
{
  imports = [
    (lib.mkRenamedOptionModule
      [ "services" "asus-numberpad-driver" ]
      [ "hardware" "asus-numberpad-driver" ]
    )
  ];

  options.hardware.asus-numberpad-driver = {
    enable = lib.mkEnableOption "Enable the Asus Numberpad Driver service.";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };

    layout = lib.mkOption {
      type = lib.types.str;
      default = "up5401ea";
      description = "The layout identifier for the numberpad driver (e.g. up5401ea). This value is required.";
    };

    config = lib.mkOption {
      type = ini.type;
      default = { };
      example = {
        main = {
          "multitouch" = 1;
          "activation_time" = "0.5";
        };
      };
      description = ''
        Configuration options for the numberpad driver.
        These options will be written to a configuration file for the driver.
      '';
    };

    display = lib.mkOption {
      type = lib.types.str;
      default = ":0";
      description = "The DISPLAY environment variable. Default is :0.";
    };

    wayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable this option to run under Wayland. Disable it for X11.";
    };

    waylandDisplay = lib.mkOption {
      type = lib.types.str;
      default = "wayland-0";
      description = "The WAYLAND_DISPLAY environment variable. Default is wayland-0.";
    };

    ignoreWaylandDisplayEnv = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, WAYLAND_DISPLAY will not be set in the service environment.";
    };

    runtimeDir = lib.mkOption {
      type = lib.types.str;
      default = "/run/user/1000/";
      description = "The XDG_RUNTIME_DIR environment variable, specifying the runtime directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure the writable directories exists
    systemd.tmpfiles.rules = [
      "d ${configDir} 0755 root root -"
      "d /var/log/asus-numberpad-driver 0755 root root -"
    ];

    # Write the configuration file to the writable directory
    environment.etc."asus-numberpad-driver/numberpad_dev".source = (
      ini.generate "numberpad_dev" cfg.config
    );

    # Enable i2c
    hardware.i2c.enable = true;

    # Add groups for numpad
    users.groups = {
      uinput = { };
      input = { };
      i2c = { };
    };

    # Add root to the necessary groups
    users.users.root.extraGroups = [
      "i2c"
      "input"
      "uinput"
    ];

    # Add the udev rule to set permissions for uinput and i2c-dev
    services.udev.extraRules = ''
      # Set uinput device permissions
      KERNEL=="uinput", GROUP="uinput", MODE="0660"
      # Set i2c-dev permissions
      SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"
    '';

    # Load specific kernel modules
    boot.kernelModules = [
      "uinput"
      "i2c-dev"
    ];

    systemd.services.asus-numberpad-driver = {
      description = "Asus NumberPad Driver";
      wantedBy = [ "default.target" ];
      startLimitBurst = 20;
      startLimitIntervalSec = 300;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/share/asus-numberpad-driver/numberpad.py ${cfg.layout} ${configDir}";
        StandardOutput = null;
        StandardError = null;
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutSec = 5;
        WorkingDirectory = "${cfg.package}";
        Environment = [
          "XDG_SESSION_TYPE=${if cfg.wayland then "wayland" else "x11"}"
          "XDG_RUNTIME_DIR=${cfg.runtimeDir}"
          "DISPLAY=${cfg.display}"
        ]
        ++ lib.optional (!cfg.ignoreWaylandDisplayEnv) "WAYLAND_DISPLAY=${cfg.waylandDisplay}";
      };
    };
  };
}
