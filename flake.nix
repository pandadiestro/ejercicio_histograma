{
  description = "devel shell";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs?ref=nixos-unstable";
    };

    zig_overlay = {
      url = "github:mitchellh/zig-overlay";
    };

    zls = {
      url = "github:zigtools/zls?ref=ce6c8f02c78e622421cfc2405c67c5222819ec03";
    };
  };

  outputs = { self, ... } @ inputs:
    let
      nixpkgs = inputs.nixpkgs;
      systems = [ "x86_64-linux" ];
    in
      {
        devShells = nixpkgs.lib.genAttrs systems (system:
          let
            pkgs = import nixpkgs { inherit system; };
            python = pkgs.python3.withPackages(python-pkgs: [
              python-pkgs.numba
            ]);
            zig = inputs.zig_overlay.packages.${system}."0.15.1";
            zls = inputs.zls.packages.${system}.default;
            stdenv = pkgs.clangStdenv;
          in {
            default = pkgs.mkShell {
              buildInputs = [
                pkgs.binutils
                pkgs.lldb
                pkgs.linuxPackages_latest.perf
                zig
                zls
              ];
            };

            shellHook = ''
              export TIMEFMT=$'real\t%mE\nuser\t%mU\nsys\t%mS';
            '';
          });
      };
}
