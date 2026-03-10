package main

import "lx"
import "core:strings"
import "core:os"
import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH      :: 1080
SCREEN_HEIGHT     :: 720
MOUSE_SENSITIVITY :: 60
FONT_SIZE         :: 24
SEEK_SKIP         :: 5 // In seconds


FONT_DATA :: #load("./resources/fonts/JetBrainsMono-Regular.ttf")

Direction :: enum { Prev, Next }
Repeat_Mode :: enum { None, Single, All }
App :: struct {
    version         : string,
    show_debug      : bool,
    tracks          : [dynamic]string,
    current_track   : int,
    track_time      : struct { total : f32, played : f32 },
    playing         : bool,
    shuffle         : bool,
    repeat          : Repeat_Mode,
    next_prev_fn    : proc(app: ^App, direction: Direction),
    cycle_repeat_fn : proc(app: ^App),
}


main :: proc() {
    app := App{
        version         = #config(VERSION, ""),
        next_prev_fn    = next_prev,
        cycle_repeat_fn = cycle_repeat,
    }

    previous_track := app.current_track
    prev_playing   := app.playing
    shuffled       := app.shuffle

    music_dir, err := os.user_music_dir(context.allocator)
    ensure(err == nil, fmt.tprintf(" >> %v", err))
    tracks, read_dir_err := os.read_directory_by_path(music_dir, -1, context.allocator)
    ensure(read_dir_err == nil, fmt.tprintf(" >> %v", err))

    for track in tracks {
        if track.type == .Regular && supported_ext(os.ext(track.fullpath)) {
            append(&app.tracks, track.fullpath)
        }
    }

    rl.SetConfigFlags({ .WINDOW_RESIZABLE })
    rl.InitWindow(SCREEN_WIDTH,SCREEN_HEIGHT, "SMP")
    defer rl.CloseWindow()

    rl.InitAudioDevice()
    defer rl.CloseAudioDevice()

    rl.SetTargetFPS(60)

    text_font := rl.LoadFontFromMemory(".ttf", raw_data(FONT_DATA), i32(len(FONT_DATA)), 50, nil, 0)
    defer rl.UnloadFont(text_font)

    icon_font := rl.LoadFontFromMemory(".ttf", raw_data(lx.ICON_FONT_DATA), i32(len(lx.ICON_FONT_DATA)),
                                        50, raw_data(lx.ICON_CODEPOINTS), i32(len(lx.ICON_CODEPOINTS)))
    defer rl.UnloadFont(icon_font)

    rl.SetTextureFilter(text_font.texture, .BILINEAR)
    rl.SetTextureFilter(icon_font.texture, .BILINEAR)

    ctx := lx.Context {
        font = { text = &text_font, icon = &icon_font },
        measure_text = measure_text,
        begin_scissor = proc(r: lx.Rect) { rl.BeginScissorMode(i32(r.x), i32(r.y), i32(r.w), i32(r.h)) },
        end_scissor   = proc() { rl.EndScissorMode() },
        scroll_offsets = make(map[u32]f32),
    }

    audio := rl.LoadMusicStream(strings.clone_to_cstring(app.tracks[app.current_track]))
    defer rl.UnloadMusicStream(audio)

    context.allocator = context.temp_allocator
    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        rl.UpdateMusicStream(audio)

        if app.playing && (app.track_time.total - app.track_time.played) <= 0.1 {
            if app.repeat == .Single {
                rl.StopMusicStream(audio)
                rl.PlayMusicStream(audio)
            } else if app.repeat == .None && app.current_track + 1 >= len(app.tracks) {
                app.playing = false
                rl.StopMusicStream(audio)
            } else {
                app.next_prev_fn(&app, direction = .Next)
            }
        }

        if app.shuffle && !shuffled {
            rand.shuffle(app.tracks[:])
            shuffled = app.shuffle
        }

        if rl.IsKeyDown(rl.KeyboardKey.LEFT_CONTROL) && rl.IsKeyPressed(rl.KeyboardKey.Q) { break }
        if rl.IsKeyPressed(rl.KeyboardKey.D)     { app.show_debug = !app.show_debug }
        if rl.IsKeyPressed(rl.KeyboardKey.SPACE) { app.playing = !app.playing }

        if rl.IsKeyPressed(rl.KeyboardKey.N)     { app.next_prev_fn(&app, direction = .Next) }
        if rl.IsKeyPressed(rl.KeyboardKey.P)     { app.next_prev_fn(&app, direction = .Prev) }
        if rl.IsKeyPressed(rl.KeyboardKey.R)     { app.cycle_repeat_fn(&app) }

        if rl.IsKeyPressed(rl.KeyboardKey.S) {
            app.shuffle = !app.shuffle
            shuffled    = !app.shuffle
        }

        if rl.IsKeyPressed(rl.KeyboardKey.RIGHT) {
            pos := SEEK_SKIP + app.track_time.played
            if pos > app.track_time.total { pos = app.track_time.total }
            rl.SeekMusicStream(audio, pos)
        }

        if rl.IsKeyPressed(rl.KeyboardKey.LEFT) {
            pos := app.track_time.played - SEEK_SKIP
            if pos < 0 { pos = app.track_time.played }
            rl.SeekMusicStream(audio, pos)
        }

        if app.current_track != previous_track {
            load_new_music(&app, &audio)
            previous_track = app.current_track
            if app.playing { rl.PlayMusicStream(audio) }
        }



        rl.ClearBackground(rl.Color{ 23, 23, 23, 255 })
        rl.BeginDrawing()
        defer rl.EndDrawing()

        time_played := rl.GetMusicTimePlayed(audio)
        total_time  := rl.GetMusicTimeLength(audio)

        app.track_time = { total = total_time, played = time_played }

        if app.playing != prev_playing {
            if app.playing {
                rl.PlayMusicStream(audio)
            } else {
                rl.PauseMusicStream(audio)
            }
            prev_playing = app.playing
        }

        rl_mp := rl.GetMousePosition()
        ctx.state.mouse_pos    = { rl_mp.x, rl_mp.y }
        ctx.state.mouse_down   = rl.IsMouseButtonDown(rl.MouseButton.LEFT)
        ctx.state.scroll_wheel = rl.GetMouseWheelMoveV().y * MOUSE_SENSITIVITY


        layout := build_layout(rl.GetRenderWidth(), rl.GetRenderHeight(), &ctx, &app)
        lx.handle_input(layout, &ctx)
        lx.render(layout, &ctx, proc(element: ^lx.Element, ctx: ^lx.Context) {
            switch &elem in element {
            case ^lx.Box:
                bg := elem.style.bg

                if ctx.state.hover_id == elem.id && elem.style.hover_bg != {} {
                    bg = elem.style.hover_bg
                }

                rl.DrawRectangleRounded(
                    { elem.bounds.x, elem.bounds.y, elem.bounds.w, elem.bounds.h },
                    elem.style.round, 16, rl.Color(bg),
                )
            case ^lx.Text:
                font_any := ctx.font.icon if elem.icon else ctx.font.text
                font, ok := font_any.(^rl.Font)
                if !ok { lx.fatal("render: Expected font to be of ^rl.Font") }
                rl.DrawTextEx(
                    font^,
                    strings.clone_to_cstring(elem.content),
                    { elem.pos.x, elem.pos.y },
                    elem.size, 0, rl.Color(elem.color),
                )
            case ^lx.Image:
                texture, ok := elem.texture.(^rl.Texture2D)
                if !ok { lx.fatal("render: Expected texture to be of ^rl.Texture2D") }
                src_rect  := rl.Rectangle{ elem.pos.x, elem.pos.y, f32(texture.width), f32(texture.height) }
                dest_rect := rl.Rectangle{ elem.pos[0], elem.pos[1], elem.bounds.x, elem.bounds.y }
                rl.DrawTexturePro(texture^, src_rect, dest_rect, { 0, 0 }, 0.0, rl.WHITE)
            }

        })
    }

}


load_new_music :: proc(app: ^App, audio: ^rl.Music) {
    rl.UnloadMusicStream(audio^)
    audio^ = rl.LoadMusicStream(strings.clone_to_cstring(app.tracks[app.current_track]))
}

supported_ext :: proc(file_ext: string) -> bool {
    supported_extensions :: []string{".mp3", ".wav", ".ogg"}
    supported := false
    for ext in supported_extensions {
        if ext == file_ext { supported = true }
    }

    return supported
}

measure_text :: proc(t: ^lx.Text, ctx: ^lx.Context) -> lx.Vec2 {
    font_any := ctx.font.icon if t.icon else ctx.font.text
    rl_font, ok := font_any.(^rl.Font)
    if !ok {
        lx.fatal("measure_text: Expected font to be of rl.Font")
    }

    v := rl.MeasureTextEx(rl_font^, strings.clone_to_cstring(t.content), f32(t.size), 1)
    return { v.x, v.y }
}

next_prev :: proc(app: ^App, direction: Direction) {
    if app.repeat == .Single { return }

    switch direction {
    case .Prev:
        new_track := app.current_track - 1
        if app.repeat == .All {
            app.current_track = len(app.tracks) - 1 if new_track < 0 else new_track
        } else {
            if new_track >= 0 { app.current_track = new_track }
        }
    case .Next:
        new_track := app.current_track + 1
        if app.repeat == .All {
            app.current_track = 0 if new_track >= len(app.tracks) else new_track
        } else {
            if new_track < len(app.tracks) { app.current_track = new_track }
        }
    }
}

cycle_repeat :: proc(app: ^App) {
    switch app.repeat {
    case .None:   app.repeat = .Single
    case .Single: app.repeat = .All
    case .All:    app.repeat = .None
    }
}


build_layout :: proc(render_w, render_h : i32, ctx: ^lx.Context, app: ^App) -> ^lx.Box {
    icon_size : i32 : 25
    icon_container_size :: icon_size + 10

    lavender_ish :: lx.Color{ 120, 120, 180, 255 }

    root := lx.box("root", 1, 1, direction = .Col, style = { gap = 7 })

    if len(app.tracks) == 0 {
        b := lx.box("no-tracks", -1, -1, direction = .Col, style = { bg = lavender_ish, align = .Center, justify = .Center, gap = 5, round = 10 })
        icon    := lx.icon(lx.ICON_FROWN, size = FONT_SIZE * 2, color = { 200, 200, 250, 255 })
        message := lx.text("No tracks found in ~/Music", size = FONT_SIZE * 1.5)
        lx.add_elements(b, icon, message)
        lx.add_elements(root, b)
        if app.show_debug { lx.add_elements(root, _debug(root, ctx, app)) }
        lx.layout(root, { 0, 0, f32(render_w), f32(render_h) }, ctx)
        return root
    }

    header := lx.box("header", -1, 30, size_mode = .Mixed, style = { padding = 1 })

    header_left := lx.box("header_l", -1, -1, style = { padding = 1 })
    lx.add_elements(header_left, lx.text(fmt.tprintf("Track: #%d/%d",app.current_track+1, len(app.tracks)+1), size = 20))
    header_right := lx.box("header_r", -1, -1, style = { padding = 1, justify = .End })
    if render_w > 400 {
        lx.add_elements(header_right, lx.text(app.version, size = 20))
    }

    lx.add_elements(header, header_left, header_right)

    track_list := lx.scroll_area("track_list", -1, -1, ctx = ctx, style = { bg = { 70, 70, 70, 150 }, gap = 7 })
    for track, index in app.tracks {
        bg := lavender_ish if app.current_track == index else lx.Color{ 120, 120, 120, 200 }
        if lx.button(track_list, os.stem(track), -1, 40, ctx = ctx, size_mode = .Mixed, justify = .Start, style = { bg = bg, round = 10 }) {
            app.current_track = index
        }
    }



    controls_height : f32 = 0.15 if render_h > 700 else 0.25
    controls := lx.box("controls", -1, controls_height, direction = .Col, style = { justify = .Start, gap = 5 })

    name_and_times := lx.box("name_and_times", -1, -1, style = { align = .Center })
    track_times := lx.box("track_times", -1, -1, style = { justify = .End, align = .Center, padding = 1 })
    times := fmt.tprintf("%s/%s", format_seconds(int(app.track_time.played)), format_seconds(int(app.track_time.total)))
    lx.add_elements(track_times, lx.text(times, size = FONT_SIZE * 0.9))
    current_track := lx.text(os.base(app.tracks[app.current_track]), size = FONT_SIZE * 0.9)
    lx.add_elements(name_and_times, current_track, track_times)
    lx.add_elements(controls, name_and_times)

    played := app.track_time.played / app.track_time.total
    lx.progress(controls, "track", -1, 15, played, style = { progress_color = lavender_ish })

    actions := lx.box("actions", -1, -1, style = { align = .Center, justify = .Center, gap = 7 })


    shuffle_icon_color := lx.Color{ 250, 250, 250, 255 } if app.shuffle else lx.Color{ 180, 180, 180, 150 }
    if lx.icon_button(actions, lx.ICON_SHUFFLE, f32(icon_container_size), f32(icon_container_size),
                        icon_size, ctx, style = { icon_color = shuffle_icon_color })
    {
        app.shuffle = !app.shuffle
    }

    if lx.icon_button(actions, lx.ICON_SKIP_BACK, f32(icon_container_size), f32(icon_container_size), icon_size, ctx) {
        app.next_prev_fn(app, direction = .Prev)
    }

    play_pause_icon := lx.ICON_PAUSE if app.playing else lx.ICON_PLAY
    size := icon_size + 15
    if lx.icon_button(actions, play_pause_icon, f32(size + 10), f32(size + 10), size, ctx) {
        app.playing = !app.playing
    }

    if lx.icon_button(actions, lx.ICON_SKIP_FORWARD, f32(icon_container_size), f32(icon_container_size), icon_size, ctx) {
        app.next_prev_fn(app, direction = .Next)
    }

    repeat_icon := lx.ICON_REPEAT
    repeat_icon_color := lx.Color{ 250, 250, 250, 255 }

    #partial switch app.repeat {
    case .None:   repeat_icon_color = { 180, 180, 180, 150 }
    case .Single: repeat_icon = lx.ICON_REPEAT_1
    }

    if lx.icon_button(actions, repeat_icon, f32(icon_container_size), f32(icon_container_size), icon_size, ctx, style = { icon_color = repeat_icon_color }) {
        app.cycle_repeat_fn(app)
    }

    lx.add_elements(controls, actions)
    lx.add_elements(root, header, track_list, controls)
    if app.show_debug { lx.add_elements(root, _debug(root, ctx, app)) }


    lx.layout(root, { 0, 0, f32(render_w), f32(render_h) }, ctx)

    return root
}

format_seconds :: proc(seconds: int) -> string {
    hours   := seconds / 3600
    minutes := (seconds % 3600) / 60
    secs    := seconds % 60

    if hours > 0 {
        return fmt.tprintf("%02d:%02d:%02d", hours, minutes, secs)
    }

    return fmt.tprintf("%02d:%02d", minutes, secs)
}

_debug :: proc(root: ^lx.Box, ctx: ^lx.Context, app: ^App) -> ^lx.Box {
    live_tree := lx.get_heirarchy(root)

    debug_box := lx.scroll_area("debug", -1, -1, ctx = ctx, style = { bg = { 70, 70, 70, 100 }, gap = 10 })
    app_state := fmt.tprintf(`App {{
    version=%s,
    current_track=%d,
    playing=%v,
    shuffle=%v,
    repeat=%v,
}}`, app.version, app.current_track + 1, app.playing, app.shuffle, app.repeat)
    lx.add_elements(debug_box, lx.text(app_state, size = FONT_SIZE), lx.text(live_tree, size = FONT_SIZE))

    return debug_box
}
