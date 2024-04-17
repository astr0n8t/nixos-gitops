{
  description = "a simple function provider to build attrsets for nixos-generators and nixos";
  outputs = { self, ... }:
  {
	buildNixOSGenerator = ({
		name ? "nixos",
		platform ? "x86-64_linux",
		format ? "raw-efi",
		modules ? [],
		nixpkgs ? null,
	}: let
		config = {
			system = platform;
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
		config = self.buildNixOSGenerator(node);
		config.modules = [ ./formats/${config.format}.nix ];
	in
		config
	);
  };
}
