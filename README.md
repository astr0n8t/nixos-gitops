# nixos-gitops

## What is this?

Wouldn't it be great if you could have your NixOS config work like k8s [fluxcd](https://fluxcd.io/)?  That's certainly what I thought.  I was disappointed when I got started with NixOS though because it didn't seem like such a thing was possible. Most of the guides I found just told you to install the OS using the normal installer and go from there.  That isn't what I wanted.

I wanted a way to create a configuration for a machine, run a build command on a machine, create a disk image that I could write directly to the storage, and then have that machine boot from it.  Then on top of this, anytime I made a change to the git repo that held the configuration, the machine would apply that configuration without me having to do anything (hence gitops).

It turns out, you can totally do this, but also it's not straight forward on how to do this.  So I created this flake to kind of act like a little bit of glue to piece this together.

## How does it work?

Basically, we need to use [nixos-generators](https://github.com/nix-community/nixos-generators/) to build our image.  And that is 90% of what we need to do, but unfortunately, this results in an image that cannot rebuild based on the original input.  Thanks to [this user's comment](https://github.com/nix-community/nixos-generators/issues/193#issuecomment-1937095713) (thanks [@JustinLex](https://github.com/JustinLex)!) the missing piece actually has to do with how the bootloader and partitions are configured.  So basically by taking Justin's method, we can create functions that generate the right config using the right modules when necessary.

### Supported Formats

Part of this project is taking files from nixos-generators and slightly modifying them to work.  At the moment only these formats are supported but other's should be easy enough to add as well:

- raw-efi
- sd-aarch64

## Show me the code

If you want to create your own image, basically just create a new flake in a git repository with this code:
```nix
{
  inputs = {
    nixos-gitops.url = "github:astr0n8t/nixos-gitops/main";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master"; # optional: for raspberry pi hw support
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixos-gitops, nixpkgs, nixos-generators, nixos-hardware, ... }:
    let
      nodes = [
        {
          name = "raspberry-pi-4";
          system = "aarch64-linux";
          format = "sd-aarch64";
          modules = [
             # Place your configuration for this node in this file
             ./my-pi-4.nix
             nixos-hardware.nixosModules.raspberry-pi-4
          ];
          nixpkgs = nixpkgs;
        }
        {
          name = "generic-x86-node";
          system = "x86_64-linux";
          format = "raw-efi";
          modules = [
             # Place your configuration for this node in this file
             ./my-x86-node.nix
          ];
          nixpkgs = nixpkgs;
        }
      ];
    in {

      # Setup x86_64 nixos-generator
      packages.x86_64-linux = builtins.listToAttrs (
        map
          ( node: { 
              "name" = node.name; 
              "value" = nixos-generators.nixosGenerate(nixos-gitops.buildNixOSGenerator(node));
            } 
          )
          ( builtins.filter(node: node.system == "x86_64-linux") nodes )  # List of nodes to generate images for
      );

      # Setup aarch64 nixos-generator
      packages.aarch64-linux = builtins.listToAttrs (
        map
          ( node: { 
              "name" = node.name; 
              "value" = nixos-generators.nixosGenerate(nixos-gitops.buildNixOSGenerator(node));
            } 
          )
          ( builtins.filter(node: node.system == "aarch64-linux") nodes )  # List of nodes to generate images for
      );


      # Setup actual NixOS config
      nixosConfigurations = builtins.listToAttrs (
        map
          ( node: { 
              "name" = node.name; 
              "value" = nixpkgs.lib.nixosSystem(nixos-gitops.buildNixOSConfig(node));
            } 
          )
          ( nodes )  # List of nodes to generate NixOS Configurations for
      );
  };
}
```

## Building

Now to actually build, if you have Docker handy just do:
```bash
# for x86_64
docker run --rm -it --platform linux/amd64 --privileged \
	-v $$(pwd):/repo -v /tmp/output:/output \
	nixpkgs/nix \
		bash -c 'git config --global --add safe.directory /repo && \
		nix  --experimental-features "nix-command flakes" build /repo#generic-x86-node && \
		cp -L result/nixos.img /output/nixos.img'

# for aarch64
docker run --rm -it --platform linux/arm64 --privileged \
	-v $$(pwd):/repo -v /tmp/output:/output \
	nixpkgs/nix \
		bash -c 'git config --global --add safe.directory /repo && \
		nix  --experimental-features "nix-command flakes" --option filter-syscalls false \
		build /repo#raspberry-pi-4 && \
		cp -L result/sd-image/nixos-sd-image-*.img.zst /output/nixos.img.zst'
sudo unzstd /tmp/output/nixos.img.zst && sudo rm /tmp/output/nixos.img.zst
```

And then your disk image will be located at `/tmp/output/nixos.img`

You can then just write this to a disk and boot the machine from it:
```
sudo dd if=/tmp/output/nixos.img of=/dev/your/disk/here
```

### Enable cross-architecture builds

If you need to build for a system that has a different architecture just do the following:
```
sudo apt install qemu binfmt-support qemu-user-static 
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

And then you should be good to go.

## GitOps

If you want to add auto-upgrades tracking your git repo, add the following:
```nix
  system.autoUpgrade = {
    enable = true;
    randomizedDelaySec = "1hr";
    allowReboot = true;
    flake = "github:<user>/<repo>#${nodeHostName}";  
    flags = [
      "-L" # print build logs
      "--refresh" # print build logs
    ];
  };
```

Note: keep in mind if your repo is private you need to give nix access to a GitHub access token

### Enabling Renovate flake.lock updates

Another cool thing about this is that you can have mend renovate keep your systems up to date.

Enable the app on GitHub marketplace [here](https://github.com/marketplace/renovate) for your repository.

Then enable support for nix and lock file maintenance in `renovate.json`: 
```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "mergeConfidence:all-badges",
    "config:recommended"
  ],
  "lockFileMaintenance": {
    "enabled": true
  },
  "nix": {
    "enabled": true
  }
}
```

Now you should get a pull request every week with updates to your flake.lock file.  If something breaks, just revert the latest commit and rebuild your systems.

## Tips and Tricks

### Too Many System Architectures

If for some reason you find yourself with more system architectures and your flake.nix is becoming filled with packages.system-name combined with the filter call, I wrote a recursive lambda to just fix the attrset. 

I'll warn you, this was a pain to program and probably a pain to debug so use at your own risk:
```nix
# This attrset evaluates to: { x86_64-linux = {"my-nix-machine" = nixos-generators.nixosGenerate {...}; ... }, aarch64-linux = {...}}
# Unfortunately we have to build a recursive function and eval it 
# since listToAttrs can't handle duplicate keys or mapping by sets rather than strings :(
# Hopefully these comments help the next person
packages = let 
# First define our recursive function
iter = (nodes: nodeSet: 
  # Base condition is when we have gone through the entire list of nodes
  # we return the attrset when that happens
  if builtins.length nodes == 0 then nodeSet else 
  # Otherwise we need to define some attrsets
  let 
    # Grab the next node out of the list of nodes
    node = builtins.elemAt nodes 0;
    # This is where we actually generate our configuration attrset
    # First declare a new attrset with our item in it but check
    # if the old attrset already has our type of system in it
    newNodeSet.${node.system} = if nodeSet ? ${node.system} then 
        # If our system type is already in the attrset then
        # we merge the existing attrset with the new one
        nodeSet.${node.system} // {
        # The new attrset is just the name of the node and the generated config
        ${node.name} = nixos-generators.nixosGenerate(
          nixos-gitops.buildNixOSGenerator(node)
        );
      }
    else {
      # Otherwise we just generate the new attrset 
      ${node.name} = nixos-generators.nixosGenerate(
        nixos-gitops.buildNixOSGenerator(node)
      );
    };
    in
      # Lastly, call the function again while removing the current node from
      # the list of nodes to evaluate and passing through our old attrset
      # merged with our new attrset
      iter (builtins.tail nodes) (nodeSet // newNodeSet)
);
in 
  # This is the initial call to the function with the list of nodes and an empty attrset
  iter nodes {};
```

### Manually upgrading the system

That can be done with the following command:
```
sudo nixos-rebuild switch -L --refresh --flake github:<user>/<repo>#
```

### Mounting the disk image

Now a cool part about this is that you can mount the disk image after you've built it.  At that point you can add things to the system that maybe you don't want in your nix config or whatever you might want.

Here's how:
```
mkdir -p /tmp/fs
LOOP_DEV=$(sudo losetup -f --show -P /tmp/output/nixos.img)
sudo mount "$LOOP_DEV"p2 /tmp/fs
```

And then the image is mounted at `/tmp/fs` 
Unfortunately, a normal chroot won't exactly work here but you can still do whatever you need.

And then when you're done umount like so:
```
sudo umount /tmp/fs
sudo losetup -d $LOOP_DEV
```

### Adding more disk formats

This one is kinda tricky because it depends on the partition format that nixos-generators creates.  Basically go [here](https://github.com/nix-community/nixos-generators/tree/master/formats) and copy the respective format file into the `formats` folder in this flake.  Then you'll want to figure out the filesystems and the bootloader.  This can be a bit tricky as sometimes its contained in more than one file.  For instance, `raw-efi` is defined in both `raw-efi.nix` and `raw.nix`.  

But once you get that down it should just work as this flake just uses the `format` key of the attrset to choose the filename.
