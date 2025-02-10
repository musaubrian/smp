#include <stdio.h>
#include <raylib.h>

#define WIDTH 800
#define HEIGHT 600
#define RADIUS 0.05
#define SEEK_HEIGHT 10
#define FONT_SIZE 15

int main(void) {
    /*SetConfigFlags(FLAG_WINDOW_RESIZABLE);*/
    SetTargetFPS(60);
    InitWindow(WIDTH, HEIGHT, "Simple Music Player");

    while (!WindowShouldClose()) {
        // CTRL+q to exit
        if (IsKeyDown(341) && IsKeyPressed(81)) break;
        BeginDrawing();

        ClearBackground(CLITERAL(Color){ 23, 23, 23, 255 });
        DrawFPS(GetScreenWidth()-100, 10);
         DrawRectangleRounded(
            CLITERAL(Rectangle){
                50,                    // x position: 50px from left
                50,                    // y position: 50px from top
                GetScreenWidth() - 100,  // width: screen width minus 100 (50px margin on each side)
                GetScreenHeight() - 200  // height: screen height minus 100 (50px margin on each side)
            },
            RADIUS/2,
            10,
            DARKGRAY
        );

/*void DrawText(const char *text, int posX, int posY, int fontSize, Color color); */
        DrawText("Playing: ", 50, GetScreenHeight()-100, FONT_SIZE, RAYWHITE);
         DrawRectangleRounded(
            CLITERAL(Rectangle){
                50,                      // x position: 50px from left
                GetScreenHeight()- 50,   // y position: 50px from top
                GetScreenWidth() - 100,  // width: screen width minus 100 (50px margin on each side)
                SEEK_HEIGHT,
            },
            RADIUS*100,
            10,
            DARKGRAY
        );
         DrawRectangleRounded(
            CLITERAL(Rectangle){
                50,                    // x position: 50px from left
                GetScreenHeight()- 50,
                GetScreenWidth()/2,
                SEEK_HEIGHT,
            },
            RADIUS*100,
            10,
            LIGHTGRAY
        );

        EndDrawing();
    }
    CloseWindow();
    return 0;
}

