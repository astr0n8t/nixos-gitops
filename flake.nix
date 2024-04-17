{
  description = "a simple function provider to build attrsets for nixos-generators and nixos";
  outputs = { self, ... }:
  {
	buildNixOSGenerator = (node: let
		config = {
			system = node.platform ? "x86_64-linux";
			format = node.format ? "raw-efi";
			modules = node.modules ? null;
			specialArgs = {
				self = self;
				nodeHostName = node.name ? "nixos";
				nixpkgs = node.nixpkgs ? null;
			};
		};
	in
		config);
	buildNixOSConfig = (node: let
		format = node.format ? "raw-efi";
		node.modules = [ ./formats/${format}.nix ];
		config = self.buildNixOSGenerator(node);
	in
		config);
  };
}
