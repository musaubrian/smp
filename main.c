#include <stdio.h>
#include <raylib.h>

int main(void) {
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    SetTargetFPS(60);
    InitWindow(800, 600, "Simple Music Player");
    while (!WindowShouldClose()) {
        BeginDrawing();
        ClearBackground(CLITERAL(Color){ 23, 23, 23, 255 });
        DrawFPS(5, 5);
        EndDrawing();
    }
    CloseWindow();
    return 0;
}

