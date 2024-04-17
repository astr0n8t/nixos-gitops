# sd-aarch64.nix
# Duplicate nixox-generators' config so that we can use nixos-rebuild
# https://github.com/nix-community/nixos-generators/blob/master/formats/sd-aarch64.nix
# Fixes failed assertions with running nixos-rebuild:
#   - The ‘fileSystems’ option does not specify your root file system.
#   - You must set the option ‘boot.loader.grub.devices’ or 'boot.loader.grub.mirroredBoots' to make the system bootable.
# In this case we need to use the generic-extlinux-compatible bootloader, not grub
# Supposedly this only works for raspberry pi's; I built this for a Raspberry Pi 4 so mileage may vary but should work
{ config, pkgs, lib, ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
  };

  # see here https://nix.dev/tutorials/nixos/installing-nixos-on-a-raspberry-pi.html
  boot = {
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
    kernelParams = [
      "cgroup_enable=cpuset" "cgroup_memory=1" "cgroup_enable=memory"
    ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
  };

}
