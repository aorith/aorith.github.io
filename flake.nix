{
  description = "Nix Flake Development Shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    forAllSystems = nixpkgs.lib.genAttrs ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"];
    eachSystemPkgs = f:
      forAllSystems (system: f (import nixpkgs {inherit system;}));
  in {
    devShells = eachSystemPkgs (pkgs: {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [hugo pandoc nodePackages.prettier];
      };
    });
  };
}
