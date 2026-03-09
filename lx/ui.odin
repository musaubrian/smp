package lx

import "core:unicode/utf8"

State :: struct {
    active_id, hover_id : u32,
    mouse_pos         : Vec2,
    mouse_down        : bool,
    scroll_wheel      : f32,
}

point_in_rect :: proc(rect: Rect, point: Vec2) -> bool {
    return point.x >= rect.x && point.x <= rect.x + rect.w &&
           point.y >= rect.y && point.y <= rect.y + rect.h
}

encode_icon :: proc(c: rune, allocator := context.allocator) -> string {
    buf, end := utf8.encode_rune(c)
    s := make([]u8, end, allocator)
    copy(s, buf[:end])
    return string(s)
}
