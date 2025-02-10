{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    gcc
    glfw
  ];

  shellHook = ''
    echo "Run make build to get started"
  '';
}
