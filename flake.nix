{
  description = "a simple function provider to build attrsets for nixos-generators and nixos";
  outputs = { self, ... }:
  {
	buildNixOSGenerator = (node: let
		config = {
			system = node.platform;
			format = node.format;
			modules = node.modules;
			specialArgs = {
				self = self;
				nodeHostName = node.name;
				nixpkgs = node.nixpkgs;
			};
		};
	in
		config);
	buildNixOSConfig = (node: let
		format = node.format;
		node.modules = [ ./formats/${format}.nix ];
		config = self.buildNixOSGenerator(node);
	in
		config);
  };
}
