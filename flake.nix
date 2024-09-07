{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    self,
    git-hooks,
    nixpkgs,
  }: let
    inherit (self) outputs;
    systems = ["aarch64-linux" "aarch64-darwin" "x86_64-darwin" "x86_64-linux"];
    forSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: (import nixpkgs {inherit system;}).extend outputs.overlays.default;
    genPkgs = func: (forSystems (system: func (pkgsFor system)));
  in {
    checks = genPkgs (pkgs: {
      git-hooks = git-hooks.lib.${pkgs.system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
          # NOTE: These do not work well with `nix flake check` due to pure environments
          # https://github.com/cachix/git-hooks.nix/issues/452
          # cargo-check.enable = true;
          # clippy = {
          #   enable = true;
          #   packageOverrides.cargo = pkgs.cargo;
          #   packageOverrides.clippy = pkgs.rustPackages.clippy;
          # };
          rustfmt = {
            enable = true;
            packageOverrides.rustfmt = pkgs.rustfmt;
          };
        };
      };
    });

    devShells = genPkgs (pkgs: {
      default = pkgs.mkShell {
        inherit (self.checks.${pkgs.system}.git-hooks) shellHook;
        packages = with pkgs; [
          rustup
          rustPackages.clippy
          rust-analyzer
          rustfmt
          lldb
        ];
        nativeBuildInputs = with pkgs; [
          clang
          gnumake
          cmake
          pkg-config
          postgresql
        ];
        LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
      };
    });

    overlays = {
      default = final: prev: {};
    };

    formatter = genPkgs (p: p.alejandra);
  };
}
