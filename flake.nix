{
  description = "A very basic flake";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/c11d08f02390aab49e7c22e6d0ea9b176394d961";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
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
    flake-utils.lib.eachDefaultSystem (system:
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
          buildInputs = [ pkgs.libudev ];
        };

      in
      {
        devShell = pkgs.mkShell {
          nativeBuildInputs = [
            rust
            espflash

            pkgs.cargo-edit
          ];
        };
      }
    )
  ;
}
