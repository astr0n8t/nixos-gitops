{
  description = "a simple function provider to build attrsets for nixos-generators and nixos";
  outputs = { self, ... }:
  {
	buildNixOSGenerator = ({
		name ? "nixos",
		system ? "x86-64_linux",
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
		node.modules = [ ./formats/raw-efi.nix ];
		config = self.buildNixOSGenerator(node);
	in
		config
	);
  };
}
