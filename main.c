#include <stdio.h>
#include <raylib.h>
#include <stdlib.h>

#define WIDTH 1080
#define HEIGHT 720
#define RADIUS 0.05
#define SEEK_HEIGHT 10
#define FONT_SIZE 18
#define PADDING 20
#define LINE_SPACE 20
#define SEEK_SKIP 10 //How many seconds ahead/behind to seek

typedef struct {
    float scrollOffset;
    Rectangle bounds;
    Rectangle content;
} ScrollableContainer;

char* joinStr(const char* base, const char* end) {
    static char path[256];
    if (snprintf(path, sizeof(path), "%s%s", base, end) < 1) {
        return NULL;
    }
    return path;
}


// Scroll container update logic
void UpdateScrollableContainer(ScrollableContainer* container) {
    float maxScroll = container->content.height - container->bounds.height + 1.5*PADDING;
    float wheel = GetMouseWheelMove();

    if (wheel != 0 && CheckCollisionPointRec(GetMousePosition(), container->bounds)) {
        container->scrollOffset += wheel * 20;
        if (container->scrollOffset > 0) container->scrollOffset = 0;
        if (container->scrollOffset < -maxScroll) container->scrollOffset = -maxScroll;
    }
}

// File list drawing function
void DrawFileList(ScrollableContainer* container, FilePathList files, Font font) {
    BeginScissorMode(container->bounds.x, container->bounds.y,
                     container->bounds.width, container->bounds.height);

    float currentY = container->bounds.y + container->scrollOffset;

    for (unsigned int i = 0; i < files.count; ++i) {
        DrawTextEx(font,
           GetFileName(files.paths[i]),
           (Vector2){ container->bounds.x + PADDING, currentY + PADDING },
           FONT_SIZE,
           2,
           RAYWHITE);

        currentY += FONT_SIZE + LINE_SPACE;
    }

    EndScissorMode();

    // Update content height for scrolling
    container->content.height = currentY - container->bounds.y;

    // Scroll Indicator
    if (container->content.height > container->bounds.height) {
        float scrollBarHeight = (container->bounds.height / container->content.height) * container->bounds.height;
        float scrollBarY = container->bounds.y - (container->scrollOffset / container->content.height) * container->bounds.height;

        DrawRectangleRounded(
            (Rectangle){
                container->bounds.x + container->bounds.width - 10,
                scrollBarY,
                5,
                scrollBarHeight
            },
            1.0,
            4,
            LIGHTGRAY
        );
    }
}

void DrawProgressBar(int screenHeight, int screenWidth, float currentTime, float totalTime) {
    float barWidth = screenWidth - 100;
    DrawRectangleRounded(
        (Rectangle){
            50,
            screenHeight - 50,
            barWidth,
            SEEK_HEIGHT,
        },
        RADIUS*100,
        10,
        DARKGRAY
    );

    DrawRectangleRounded(
        (Rectangle){
            50,
            screenHeight - 50,
            (currentTime / totalTime) * barWidth,
            SEEK_HEIGHT,
        },
        RADIUS*100,
        10,
        LIGHTGRAY
    );
}

int main(void) {
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    SetTargetFPS(60);

    InitWindow(WIDTH, HEIGHT, "Simple Music Player");
    InitAudioDevice();

    char* home = getenv("HOME");
    char* musicDir = "/Music";
    char* toMusic = joinStr(home, musicDir);
    if (toMusic == NULL) {
        fprintf(stderr, "Failed to create music path\n");
        return 1;
    }

    // Load font and setup text
    SetTextLineSpacing(LINE_SPACE);
    Font spaceMono = LoadFontEx("./fonts/SpaceMono-Regular.ttf", FONT_SIZE*2, 0, 250);

    // Check directory and load files
    if(!DirectoryExists(toMusic)) {
        fprintf(stderr, "Failed to load directory %s", toMusic);
        return 1;
    }
    FilePathList files = LoadDirectoryFiles(toMusic);

    // Initialize scrollable container
    ScrollableContainer fileList = {
        .scrollOffset = 0,
        .bounds = (Rectangle) {
            50, 50,
            GetScreenWidth() - 100,
            GetScreenHeight() - 200,
        },
        .content = (Rectangle){
            50,
            50,
            GetScreenWidth() - 100,
            0
        }
    };


    int activeTrack = 0;
    Music audio = LoadMusicStream(files.paths[activeTrack]);
    bool pause = true;

    while (!WindowShouldClose()) {
        fileList.bounds = (Rectangle){
            50,
            50,
            GetScreenWidth() - 100,
            GetScreenHeight() - 200
        };

        UpdateScrollableContainer(&fileList);
        UpdateMusicStream(audio);

        // Exit on CTRL+Q
        if (IsKeyDown(KEY_LEFT_CONTROL) && IsKeyPressed(KEY_Q)) break;

        if (IsKeyPressed(KEY_SPACE)) {
            pause = !pause;

            if (pause) PauseMusicStream(audio);
            else PlayMusicStream(audio);
        }

        if (IsKeyPressed(KEY_N)) {
            if ((unsigned int)(activeTrack + 1) < files.count) {
                activeTrack += 1;
            } else {
                // Loop around if at the end
                activeTrack = 0;
            }

            UnloadMusicStream(audio);
            audio = LoadMusicStream(files.paths[activeTrack]);
            PlayMusicStream(audio);
        }

        if (IsKeyPressed(KEY_P)) {
            if (activeTrack <= 0) {
                activeTrack = files.count - 1;
            } else {
                activeTrack -= 1;
            }

            UnloadMusicStream(audio);
            audio = LoadMusicStream(files.paths[activeTrack]);
            PlayMusicStream(audio);
        }

        BeginDrawing();
        ClearBackground(CLITERAL(Color){ 23, 23, 23, 255 });

        DrawFPS(GetScreenWidth()-100, 10);

        DrawRectangleRounded(fileList.bounds, RADIUS/2, 10, DARKGRAY);
        DrawFileList(&fileList, files, spaceMono);

        if (!pause) {
            DrawTextEx(
                spaceMono,
                "Playing",
                (Vector2){50, (float)GetScreenHeight()-100},
                FONT_SIZE,
                2,
                RAYWHITE
            );
        } else {
            DrawTextEx(
                spaceMono,
                "Paused",
                (Vector2){50, (float)GetScreenHeight()-100},
                FONT_SIZE,
                2,
                RAYWHITE
            );

        }
        float timeAudioPlayed = GetMusicTimePlayed(audio);
        float totalAudioTime = GetMusicTimeLength(audio);
        if(IsKeyPressed(KEY_RIGHT)) {
            float pos = SEEK_SKIP + timeAudioPlayed;
            if (pos > totalAudioTime) pos = totalAudioTime;
            SeekMusicStream(audio, pos);
        }

        if(IsKeyPressed(KEY_LEFT)) {
            float pos = timeAudioPlayed - SEEK_SKIP;
            if (pos < 0) pos = 0;
            SeekMusicStream(audio, pos);
        }

        if (totalAudioTime - timeAudioPlayed <= 0.1) {
            if ((unsigned int)(activeTrack + 1) < files.count) {
                activeTrack += 1;
            } else {
                activeTrack = 0;
            }

            UnloadMusicStream(audio);
            audio = LoadMusicStream(files.paths[activeTrack]);
            PlayMusicStream(audio);
        }

        DrawProgressBar(GetScreenHeight(), GetScreenWidth(),timeAudioPlayed,totalAudioTime);
        EndDrawing();
    }

    UnloadMusicStream(audio);
    UnloadFont(spaceMono);
    UnloadDirectoryFiles(files);
    CloseAudioDevice();
    CloseWindow();

    return 0;
}
