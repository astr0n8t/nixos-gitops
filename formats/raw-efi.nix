# raw-efi.nix
# Duplicate nixox-generators' config so that we can use nixos-rebuild
# https://github.com/nix-community/nixos-generators/blob/master/formats/raw-efi.nix
# Fixes failed assertions with running nixos-rebuild:
#   - The ‘fileSystems’ option does not specify your root file system.
#   - You must set the option ‘boot.loader.grub.devices’ or 'boot.loader.grub.mirroredBoots' to make the system bootable.
{ config, pkgs, lib, ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };
  boot = {
    growPartition = true;
    kernelParams = ["console=ttyS0"];
    loader.grub = {
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
    };
    loader.timeout = 0;
    initrd.availableKernelModules = ["uas"];
  };
}
