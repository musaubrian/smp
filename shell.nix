{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    gcc
    raylib
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
