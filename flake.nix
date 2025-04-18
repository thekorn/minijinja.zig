{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    zig-overlay.url = "github:mitchellh/zig-overlay";
    zls-master = {
      url = "github:zigtools/zls";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.zig-overlay.follows = "zig-overlay";
    };
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    zig-overlay,
    zls-master,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = (import nixpkgs) {
          inherit system;
        };
      in {
        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs;
            [
              rustup
              #zig-overlay.packages.${system}."master-2025-02-01"
              #zls-master.packages.${system}.default
              zig
              zls
            ]
            ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [glibc]);

          shellHook = ''
            # We unset some NIX environment variables that might interfere with the zig
            # compiler.
            # Issue: https://github.com/ziglang/zig/issues/18998
            unset NIX_CFLAGS_COMPILE
            unset LD_LIBRARY_PATH
            #unset NIX_LDFLAGS
          '';

          PKG_CONFIG_PATH =
            if pkgs.stdenv.isLinux
            then "${pkgs.glibc}/lib/pkgconfig"
            else "";
        };
      }
    );
}
