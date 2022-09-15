{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-22.05";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs
          {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };
        riscvPkgs = import nixpkgs {
          localSystem = "${system}";
          crossSystem = {
            config = "riscv32-unknown-linux-gnu";
            abi = "lp32";
          };
        };
        rust = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default.override {
          targets = [ "riscv32imc-unknown-none-elf" ];
          extensions = [ "rust-src" "clippy" "cargo" "rustfmt-preview" ];
        });
        rustPlatform = pkgs.makeRustPlatform {
          cargo = rust;
          rustc = rust;
        };
        espflash = rustPlatform.buildRustPackage rec {
          pname = "espflash";
          version = "1.6.0";

          src = pkgs.fetchFromGitHub {
            owner = "esp-rs";
            repo = pname;
            rev = "v${version}";
            hash = "sha256-YQ621YbdEy2sS4uEYvgnQU1G9iW5SpWNObPH4BfyeF0=";
          };

          cargoSha256 = "sha256-do0rjujlLyEjCnKfbFnblyxrGYguDQ70j9KJcUAYi+w=";

          doCheck = false;

          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = [ pkgs.udev ];
        };
        espmonitor = rustPlatform.buildRustPackage rec {
          pname = "espmonitor";
          version = "0.10.0";

          src = pkgs.fetchFromGitHub {
            owner = "esp-rs";
            repo = pname;
            rev = "v${version}";
            hash = "sha256-hWFdim84L2FfG6p9sEf+G5Uq4yhp5kv1ZMdk4sMHa+4=";
          };

          cargoSha256 = "sha256-d0tN6NZiAd+RkRy941fIaVEw/moz6tkpL0rN8TZew3g=";

          doCheck = false;

          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = [ pkgs.udev ];
        };
        ldproxy = rustPlatform.buildRustPackage rec {
          pname = "ldproxy";
          version = "0.3.2";

          src = pkgs.fetchFromGitHub {
            owner = "esp-rs";
            repo = "embuild";
            rev = "${pname}-v${version}";
            sha256 = "sha256-CPMcFzfP/l1g04sBLWj2pY76F94mNsr1RGom1sfY23I=";
          };

          doCheck = false;

          buildAndTestSubdir = "ldproxy";

          nativeBuildInputs = [
            pkgs.pkg-config
          ];

          buildInputs = [
            pkgs.udev
          ];

          cargoSha256 = "sha256-u4G5LV/G6Iu3FUeY2xdeXgVdiXLpGIC2UUYbUr0w3n0=";
        };

      in
      {
        devShell = pkgs.mkShell {
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          IDF_MAINTAINER = "yes";
          nativeBuildInputs = [
            rust
            espflash
            espmonitor
            ldproxy
          ];
        };
      }
    )
  ;
}
