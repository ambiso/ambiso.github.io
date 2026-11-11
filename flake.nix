{
  description = "ambiso's blog";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Zola 0.23 changes Tera syntax; the current theme uses the 0.22 macros.
    zola-nixpkgs.url = "github:NixOS/nixpkgs/a50ab42bfe17b6cb772d43a8b9c8fef9d650c556";
    self.submodules = true;
  };

  outputs =
    { self, nixpkgs, zola-nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "ambiso-blog";
            version = "1";
            src = self;
            nativeBuildInputs = [ zola-nixpkgs.legacyPackages.${system}.zola ];
            SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
            dontConfigure = true;
            buildPhase = ''
              runHook preBuild
              zola build --base-url https://robinleander.eu
              runHook postBuild
            '';
            installPhase = ''
              runHook preInstall
              cp -r public $out
              runHook postInstall
            '';
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [ zola-nixpkgs.legacyPackages.${system}.zola ];
          };
        }
      );
    };
}
