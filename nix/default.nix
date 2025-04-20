{
  lib,
  python311Packages,
  pkgs,
}:

let
  # Define the Python packages required
  pythonPackages = pkgs.python311.withPackages (
    ps: with ps; [
      numpy
      libevdev
      xlib
      pyinotify
      smbus2
      pyasyncore
      pywayland
      xkbcommon
      systemd
    ]
  );
in
python311Packages.buildPythonPackage {
  pname = "asus-numberpad-driver";
  version = "6.5.0";
  src = lib.cleanSource ../.;

  format = "other";

  propagatedBuildInputs = with pkgs; [
    ibus
    libevdev
    curl
    xorg.xinput
    i2c-tools
    libxml2
    libxkbcommon
    libgcc
    gcc
    pythonPackages # Python dependencies already include python311
  ];

  doCheck = false;
  doBuild = false;

  # Install files for driver and layouts
  installPhase = ''
    mkdir -p $out/{share/asus-numberpad-driver,bin}

    # Copy the driver script
    cp numberpad.py $out/share/asus-numberpad-driver/

    # mainPrograms are searched at $out/bin
    ln -s $out/share/asus-numberpad-driver/numberpad.py $out/bin/numberpad.py

    # Copy layouts directory if it exists, and remove __pycache__ if present
    if [ -d layouts ]; then
      cp -r layouts $out/share/asus-numberpad-driver/
      rm -rf $out/share/asus-numberpad-driver/layouts/__pycache__
    fi
  '';

  meta = {
    homepage = "https://github.com/asus-linux-drivers/asus-numberpad-driver";
    description = "Linux driver for NumberPad(2.0) on Asus laptops.";
    license = lib.licenses.gpl2;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ asus-linux-drivers ];
    mainProgram = "numberpad.py";
  };
}
