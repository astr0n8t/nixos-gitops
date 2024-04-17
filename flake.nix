{
  description = "a simple function provider to build attrsets for nixos-generators and nixos";
  outputs = { self, ... }:
  {
	buildNixOSGenerator = ({
		# Define some sane defaults so hopefully the universe doesn't break
		name ? "nixos",
		system ? "x86_64-linux",
		format ? "raw-efi",
		modules ? [],
		nixpkgs ? null,
	}: let
		# All this really does is output an attrset that matches what nixosGenerate expects
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
		# Return the config
		config
	); 
	buildNixOSConfig = (
	node: let
		# We can use the other function as a starting point
		# which ensures we have some sane defaults 
		generated = self.buildNixOSGenerator(node);
		# Now we define the attrset that matches what nixosSystem expects
		config = {
			system = generated.system;
			# Here is the secret sauce where we add our modified format file
			# that adds the filesystems and bootloaders to our configuration
			modules = generated.modules ++ [ ./formats/${node.format}.nix ];
			specialArgs = generated.specialArgs;
		};
	in
		# Return the config
		config
	);
  };
}
