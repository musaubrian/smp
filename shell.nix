{
  pkgs ? import <nixpkgs> {},
  unstable ? import (fetchTarball "https://github.com/nixos/nixpkgs/archive/nixos-unstable.tar.gz") {},
}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    gcc
    unstable.raylib
    wayland
    wayland-protocols
    libGL
    xorg.libX11
    libxkbcommon
  ];
  shellHook = ''
    export RAYLIB_WAYLAND_LIBRARY_PATH="${pkgs.wayland}/lib/libwayland-client.so"
  '';
}
