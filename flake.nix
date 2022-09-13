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
    esp-dev.url = "github:mirrexagon/nixpkgs-esp-dev";
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, esp-dev, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs
          {
            inherit system;
            overlays = [ rust-overlay.overlays.default esp-dev.overlay ];
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
          nativeBuildInputs = [
            rust
            espflash
            ldproxy

            pkgs.python39Packages.pip
            pkgs.python39Packages.virtualenv
            pkgs.cargo-edit
            pkgs.gcc-riscv32-esp32c3-elf-bin
            (pkgs.esp-idf.overrideAttrs (oldAttrs:
              rec {
                src =
                  let
                    owner = "espressif";
                    repo = "esp-idf";
                  in
                  builtins.fetchGit {
                    url = "https://github.com/${owner}/${repo}.git";
                    ref = "v4.4.1";
                    rev = "1329b19fe494500aeb79d19b27cfd99b40c37aec"; # v4.4.1
                    allRefs = true;
                    submodules = true;
                  };
                installPhase = oldAttrs.installPhase + ''
                  cp -r $src/.git $out/.git
                '';
              }))
            pkgs.esptool

            # Tools required to use ESP-IDF.
            pkgs.git
            pkgs.wget
            pkgs.gnumake

            pkgs.flex
            pkgs.bison
            pkgs.gperf
            pkgs.pkgconfig

            pkgs.cmake
            pkgs.ninja

            pkgs.ncurses5
          ];
        };
      }
    )
  ;
}
