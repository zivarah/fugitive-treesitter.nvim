{
  pkgs ? import <nixpkgs> { },
}:

let
  # Third-party docset that provides completion and documentation for the Neovim
  # API to fennel-ls. Sourced from the official Fennel wiki:
  # https://wiki.fennel-lang.org/LanguageServer
  nvim-docset = pkgs.fetchFromSourcehut {
    owner = "~micampe";
    repo = "fennel-ls-nvim-docs";
    rev = "a072d3f5d2dd98cf0411cd16446a0f3c96ee7938";
    hash = "sha256-DpLNcaH3JRrXO8Ds0ZlzoBQFSaOD8xK5+iYZSICBqao=";
  };

  # fennel-ls reads docsets from $XDG_DATA_HOME/fennel-ls/docsets.
  fennel-ls-data-home = pkgs.linkFarm "fennel-ls-data-home" {
    "fennel-ls/docsets/nvim.lua" = "${nvim-docset}/nvim.lua";
  };

  # The wrapper points fennel-ls at its own data home, so the docset stays
  # invisible to every other program in the shell.
  fennel-ls = pkgs.symlinkJoin {
    name = "fennel-ls-with-nvim-docset";
    paths = [ pkgs.fennel-ls ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/fennel-ls --set XDG_DATA_HOME ${fennel-ls-data-home}
    '';
  };

  # The latest fnlfmt registers a compiler plugin that warns on fennel versions
  # past 1.5.1.
  fennel-for-fnlfmt = pkgs.luaPackages.fennel.overrideAttrs {
    version = "1.5.1-1";

    src = pkgs.fetchFromGitHub {
      owner = "bakpakin";
      repo = "Fennel";
      tag = "1.5.1";
      hash = "sha256-ciXElwX/F8YCFA6C0F3+8lnUPQlKYpcdpagAjoXZpyY=";
    };
  };

  # nixpkgs still packages 0.3.2. There is no more recent version, but that's
  # very old and there are a few improvements like not converting hex -> dec.
  fnlfmt =
    (pkgs.fnlfmt.override {
      luaPackages = pkgs.luaPackages // {
        fennel = fennel-for-fnlfmt;
      };
    }).overrideAttrs
      (old: rec {
        version = "0.3.3-dev";

        src = pkgs.fetchFromSourcehut {
          owner = "~technomancy";
          repo = "fnlfmt";
          rev = "e059775b9ce38cdcf3c1d5458ca2e5f2ecf698b3";
          hash = "sha256-PG/bEkGkgaIBAlQGvDN9C+As3H6hGUskF8vhMD4mZmY=";
        };

        meta = old.meta // {
          changelog = "${src.meta.homepage}/tree/${src.rev}/changelog.md";
        };
      });
in
pkgs.mkShell {
  packages = [
    # pkgs.luaPackages.fennel
    fennel-ls
    fnlfmt
  ];
}
