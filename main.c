#include <stdio.h>
#include <time.h>
#include <raylib.h>
#include <stdlib.h>
#include <libgen.h>
#include <stdint.h>
#include <string.h>

#define WIDTH 1080
#define HEIGHT 720
#define RADIUS 0.05
#define SEEK_HEIGHT 10
#define FONT_SIZE 18
#define PADDING 20
#define LINE_SPACE 20
#define SEEK_SKIP 10 //How many seconds ahead/behind to seek


// TODO: probably handle this better instead of like paths
char *joinStr(const char *base, const char *end) {
    static char path[256];
    if (snprintf(path, sizeof(path), "%s%s", base, end) < 1) {
        return NULL;
    }
    return path;
}

int get_unique_random(int prev_val, int max_val)
{
    int new_rand_val;

    do {
        new_rand_val = random() % max_val;
    } while (new_rand_val == prev_val);

    return new_rand_val;
}

int shuffle_track(int currentTrack, int totalTracks, char *opt)
{
    if (strcmp(opt,"prev"))
    {
        return get_unique_random(currentTrack, totalTracks);
    }
    if (strcmp(opt,"next"))
    {
        return get_unique_random(currentTrack, totalTracks);
    }
    return -1;
}

void DrawProgressBar(int screenHeight, int screenWidth, float currentTime, float totalTime) {
    float barWidth = screenWidth - 100;
    Rectangle seek_track_background = {
        .x = 50,
        .y = screenHeight - 50,
        .width = barWidth,
        .height = SEEK_HEIGHT
    };

    DrawRectangleRounded(seek_track_background, RADIUS*100, 10, DARKGRAY);

    Rectangle seek_track_active = {
        .x = 50,
        .y = screenHeight - 50,
        .width = (currentTime / totalTime) * barWidth,
        .height = SEEK_HEIGHT,
    };

    DrawRectangleRounded(seek_track_active, RADIUS*100, 10, LIGHTGRAY);
}

// Implementation was taken from musializer github.com/tsoding/musializer
void DrawTrackList(FilePathList tracks,Font font, unsigned int activeTrack, Rectangle panel_boundary) {
    DrawRectangleRounded(panel_boundary, RADIUS/3, 10, DARKGRAY);

    Vector2 mouse = GetMousePosition();

    float scroll_bar_width = panel_boundary.width*0.01;
    float item_size = panel_boundary.width*0.07;

    float visible_area_size = panel_boundary.height;
    float entire_scrollable_area = item_size*tracks.count;

    static float panel_scroll = 0;
    static float panel_velocity = 0;
    panel_velocity *= 0.9;
    if (CheckCollisionPointRec(mouse, panel_boundary)) {
        panel_velocity += GetMouseWheelMove()*item_size*8;
    }
    panel_scroll -= panel_velocity*GetFrameTime();

    static bool scrolling = false;
    static float scrolling_mouse_offset = 0.0f;
    if (scrolling) {
        panel_scroll = (mouse.y - panel_boundary.y - scrolling_mouse_offset)/visible_area_size*entire_scrollable_area;
    }

    float min_scroll = 0;
    if (panel_scroll < min_scroll) panel_scroll = min_scroll;
    float max_scroll = entire_scrollable_area - visible_area_size;
    if (max_scroll < 0) max_scroll = 0;
    if (panel_scroll > max_scroll) panel_scroll = max_scroll;
    float panel_padding = item_size*0.1;


    BeginScissorMode(panel_boundary.x, panel_boundary.y, panel_boundary.width, panel_boundary.height);
    for (unsigned int i = 0; i < tracks.count; ++i) {
        Rectangle item_boundary = {
            .x = panel_boundary.x + panel_padding,
            .y = i*item_size + panel_boundary.y + panel_padding - panel_scroll,
            .width = panel_boundary.width - panel_padding*2 - scroll_bar_width,
            .height = item_size - panel_padding*2,
        };
        Color color;
        if (i == activeTrack) {
            color = BLUE;
        } else {
            color = GRAY;
        }
        DrawRectangleRounded(item_boundary, RADIUS*5, 10, color);

        const char *text = GetFileName(tracks.paths[i]);
        float fontSize = item_boundary.height*0.5;
        float text_padding = PADDING;

        Vector2 size = MeasureTextEx(font, text, fontSize, 0);
        Vector2 position = {
            .x = item_boundary.x + text_padding,
            .y = item_boundary.y + item_boundary.height*0.5 - size.y*0.5,
        };

        DrawTextEx(font, text, position, fontSize, 0, WHITE);
    }


    if (entire_scrollable_area > visible_area_size) { // Is scrolling needed
        float t = visible_area_size/entire_scrollable_area;
        float q = panel_scroll/entire_scrollable_area;
        Rectangle scroll_bar_area = {
            .x = panel_boundary.x + panel_boundary.width - scroll_bar_width,
            .y = panel_boundary.y,
            .width = scroll_bar_width,
            .height = panel_boundary.height,
        };
        Rectangle scroll_bar_boundary = {
            .x = panel_boundary.x + panel_boundary.width - scroll_bar_width - 2,
            .y = panel_boundary.y + panel_boundary.height*q,
            .width = scroll_bar_width,
            .height = panel_boundary.height*t,
        };
        DrawRectangleRounded(scroll_bar_boundary, RADIUS*100, 20, RAYWHITE);

        if (scrolling) {
            if (IsMouseButtonReleased(MOUSE_LEFT_BUTTON)) {
                scrolling = false;
            }
        } else {
            if (CheckCollisionPointRec(mouse, scroll_bar_boundary)) {
                if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
                    scrolling = true;
                    scrolling_mouse_offset = mouse.y - scroll_bar_boundary.y;
                }
            } else if (CheckCollisionPointRec(mouse, scroll_bar_area)) {
                if (IsMouseButtonReleased(MOUSE_LEFT_BUTTON)) {
                    if (mouse.y < scroll_bar_boundary.y) {
                        panel_velocity += item_size*16;
                    } else if (scroll_bar_boundary.y + scroll_bar_boundary.height < mouse.y){
                        panel_velocity += -item_size*16;
                    }
                }
            }
        }
    }

    EndScissorMode();
}


int main(void) {
    srandom(time(NULL));
    SetConfigFlags(FLAG_WINDOW_RESIZABLE);
    SetTargetFPS(60);

    InitWindow(WIDTH, HEIGHT, "Simple Music Player");
    InitAudioDevice();

    char *home = getenv("HOME");
    char *musicDir = "/Music";
    char *toMusic = joinStr(home, musicDir);
    if (toMusic == NULL) {
        fprintf(stderr, "Failed to create music path\n");
        return 1;
    }

    SetTextLineSpacing(LINE_SPACE);
    Font spaceMono = LoadFontEx("fonts/SpaceMono-Regular.ttf", FONT_SIZE*2, 0, 250);

    if(!DirectoryExists(toMusic)) {
        fprintf(stderr, "Failed to load directory %s", toMusic);
        return 1;
    }

    FilePathList files = LoadDirectoryFilesEx(toMusic, ".wav;.ogg;.mp3", true);

    int enableShuffle = false;
    int currentTrack = 0;
    Music audio = LoadMusicStream(files.paths[currentTrack]);
    bool pause = true;

    while (!WindowShouldClose()) {

        UpdateMusicStream(audio);

        // Exit on CTRL+Q
        if (IsKeyDown(KEY_LEFT_CONTROL) && IsKeyPressed(KEY_Q)) break;
        if (IsKeyPressed(KEY_S))
        {
            enableShuffle = !enableShuffle;
        }

        if (IsKeyPressed(KEY_SPACE)) {
            pause = !pause;

            if (pause) PauseMusicStream(audio);
            else PlayMusicStream(audio);
        }

        if (IsKeyPressed(KEY_N)) {
            if (enableShuffle)
            {
                int newTrack = shuffle_track(currentTrack, files.count, "next");
                if (newTrack == -1)
                {
                    fprintf(stderr, "invalid argument, expected [next/prev]");
                }
                currentTrack = newTrack;
            }
            if ((unsigned int)(currentTrack + 1) < files.count) {
                currentTrack += 1;
            } else {
                currentTrack = 0;
            }

            UnloadMusicStream(audio);
            audio = LoadMusicStream(files.paths[currentTrack]);
            if (!pause) PlayMusicStream(audio);
        }

        if (IsKeyPressed(KEY_P)) {
            if (enableShuffle)
            {
                int newTrack = shuffle_track(currentTrack, files.count, "prev");
                if (newTrack == -1)
                {
                    fprintf(stderr, "invalid argument, expected [next/prev]");
                }
                currentTrack = newTrack;
            }
            if (currentTrack <= 0) {
                currentTrack = files.count - 1;
            } else {
                currentTrack -= 1;
            }

            UnloadMusicStream(audio);
            audio = LoadMusicStream(files.paths[currentTrack]);
            if (!pause) PlayMusicStream(audio);
        }

        BeginDrawing();
        ClearBackground(CLITERAL(Color){ 23, 23, 23, 255 });

        DrawFPS(GetScreenWidth()-100, 10);

        Rectangle trackListBounds = {
           .x = 50,
           .y = 50,
           .width = GetScreenWidth() - 100,
           .height = GetScreenHeight() - 200
        };
        DrawTrackList(files,spaceMono, currentTrack, trackListBounds);
        if (enableShuffle)
        {
            DrawTextEx(
                spaceMono,
                "Shuffle ON",
                (Vector2){50, (float)GetScreenHeight()-130},
                FONT_SIZE,
                2,
                RAYWHITE
            );
        }

        if (!pause) {
            DrawTextEx(
                spaceMono,
                joinStr("Playing: ", basename(files.paths[currentTrack])),
                (Vector2){50, (float)GetScreenHeight()-100},
                FONT_SIZE,
                2,
                RAYWHITE
            );
        } else {
            DrawTextEx(
                spaceMono,
                joinStr("Paused: ", basename(files.paths[currentTrack])),
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
            if (pos < 0) pos = timeAudioPlayed;
            SeekMusicStream(audio, pos);
        }

        if (totalAudioTime - timeAudioPlayed <= 0.1) {
            if ((unsigned int)(currentTrack + 1) < files.count) {
                currentTrack += 1;
            } else {
                currentTrack = 0;
            }

            UnloadMusicStream(audio);
            audio = LoadMusicStream(files.paths[currentTrack]);
            PlayMusicStream(audio);
        }

        DrawProgressBar(GetScreenHeight(), GetScreenWidth(), timeAudioPlayed, totalAudioTime);
        EndDrawing();
    }

    UnloadMusicStream(audio);
    UnloadFont(spaceMono);
    UnloadDirectoryFiles(files);
    CloseAudioDevice();
    CloseWindow();

    return 0;
}

