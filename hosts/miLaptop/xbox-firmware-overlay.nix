{ ... }:
let
  # Work around nixpkgs#471331: these dongle firmware archives currently
  # fail to download from Microsoft's update catalog.
  mkDummyFirmware =
    prev: name: fileName:
    prev.runCommand "dummy-${name}-firmware" { } ''
      mkdir -p $out/lib/firmware
      echo "dummy" > $out/lib/firmware/${fileName}
      echo "This is a dummy firmware to bypass download errors" > $out/README
    '';
in
{
  nixpkgs.overlays = [
    (_: prev: {
      xow_dongle-firmware = mkDummyFirmware prev "xow" "xow_placeholder.bin";
      xone-dongle-firmware = mkDummyFirmware prev "xone" "xone_placeholder.bin";
    })
  ];
}
