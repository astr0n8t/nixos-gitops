{
  description = "a simple function provider to build attrsets for nixos-generators and nixos";
  outputs = { self, ... }:
  {
	buildNixOSGenerator = ({
		name ? "nixos",
		system ? "x86_64-linux",
		format ? "raw-efi",
		modules ? [],
		nixpkgs ? null,
	}: let
		config = {
			system = system;
			format = format;
			modules = modules;
			specialArgs = {
				self = self;
				nodeHostName = name;
				nixpkgs = nixpkgs;
			};
		};
	in
		config
	);
	buildNixOSConfig = (
	node: let
		bootloader-module = [ ./formats/${node.format}.nix ];
		generated = self.buildNixOSGenerator(node);
		config = {
			system = generated.system;
			modules = generated.modules ++ bootloader-module;
			specialArgs = generated.specialArgs;
		};
	in
		config
	);
  };
}
