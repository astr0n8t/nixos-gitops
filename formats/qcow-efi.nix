{ config, lib, pkgs, modulesPath, ... }:
{
  # for virtio kernel drivers
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];

  config = {
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      autoResize = true;
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
    };

    boot.growPartition = true;
    boot.kernelParams = map (c: "console=${c}") config.boot.consoles;
    boot.loader.grub.device = "nodev";

    boot.loader.grub.efiSupport = true;
    boot.loader.grub.efiInstallAsRemovable = true;
    boot.loader.timeout = 5;

  };
}
