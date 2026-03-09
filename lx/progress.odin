package lx

import "core:fmt"

_Progress_Fill    :: Color{ 100, 180, 100, 255 }
_Progress_Track   :: Color{ 60,  60,  60,  255 }
_Progress_Padding :: 2

progress :: proc(parent: ^Box, debug_label: string, w, h: f32, value: f32, size_mode := Size_Mode.Mixed, style := Style{}) {
    track_padding := style.padding if style.padding > 0 else _Progress_Padding
    bg := style.bg if style.bg != {} else _Progress_Track

    track := box(debug_label, w, h, size_mode = size_mode, style = { bg = bg , round = style.round, padding = track_padding })
    fill_w := clamp(value, 0, 1)

    fill_bg := style.progress_color if style.progress_color != {} else _Progress_Fill
    fill := box(fmt.tprintf("%s-fill", debug_label), fill_w, 1, style = { bg = fill_bg, round = style.round })
    add_elements(track, fill)
    add_elements(parent, track)
}
