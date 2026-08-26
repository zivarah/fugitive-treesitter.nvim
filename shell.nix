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
in
pkgs.mkShell {
  packages = [
    fennel-ls
    pkgs.fnlfmt
  ];
}
