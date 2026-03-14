#+feature dynamic-literals
package lx

import "core:hash"
import "core:fmt"
import "core:os"
import "core:strings"

Direction :: enum { Row, Col }
Alignment :: enum { Start, Center, End }
Size_Mode :: enum { Relative, Mixed }

Element   :: union { ^Box, ^Text, ^Image }

Box  :: struct {
    parent      : ^Box,
    id          : u32,
    debug_label : string,
    w, h        : f32,
    size_mode   : Size_Mode,
    direction   : Direction,
    elements    : [dynamic]Element,
    bounds      : Rect,
    hidden      : bool,
    style       : Style,
    scroll      : Scroll_State,
}

Scroll_State :: struct {
    enabled      : bool,
    offset       : f32,
    content_size : f32,
}

Text :: struct {
    content     : string,
    size        : f32,
    color       : Color,
    pos, bounds : Vec2,
    hidden      : bool,
    icon        : bool,
}

Image :: struct {
    debug_label : string,
    texture     : any,
    pos, bounds : Vec2,
}

Style :: struct {
    padding        : int,
    gap            : int,
    round          : f32,
    bg             : Color,
    hover_bg       : Color,
    justify        : Alignment,
    align          : Alignment,
    wrap           : bool,
    track_color    : Color,
    thumb_color    : Color,
    progress_color : Color,
}

Font :: struct {
    text : any,
    icon : any,
}

Context :: struct {
    font           : Font,
    measure_text   : proc(t: ^Text, ctx: ^Context) -> Vec2,
    begin_scissor  : proc(rect: Rect),
    end_scissor    : proc(),
    state          : State,
    scroll_offsets : map[u32]f32,
    floaters       : map[u32]^Box,
}

Rect  :: struct { x, y, w, h: f32 }
Vec2  :: distinct [2]f32
Color :: distinct [4]u8

// Defaults
_Text_Size         : f32 : 25.0
_Text_Color        :: Color{ 255, 255, 255, 255 }
_Box_Padding       :: 5
_Scrollbar_Size    : f32 : 5.0
_Scrollthumb_Round : f32 : 10.0
_Track_Color       :: Color{ 30,  30,  30,  255 }
_Thumb_Color       :: Color{ 140, 140, 140, 255 }
_Default_Bg        :: Color{ 70,  70,  80,  255 }

make_id :: proc(label: string, parent: ^Box = nil) -> u32 {
    seed : u32 = 2166136261
    if parent != nil {
        seed = parent.id ~ u32(len(parent.elements))
    }
    return hash.fnv32a(transmute([]u8)label, seed)
}

box :: proc(label: string, w, h : f32, direction: Direction = .Row, size_mode: Size_Mode = .Relative,
            hidden := false, parent : ^Box = nil, style := Style{}, allocator := context.allocator) -> ^Box {
    b := new(Box)

    style_with_defaults := Style{
        // Need to find a way of opting out of default padding
        padding  = style.padding if style.padding > 0 else _Box_Padding,
        gap      = style.gap,
        round    = style.round,
        bg       = style.bg,
        hover_bg = style.hover_bg,
        justify  = style.justify,
        align    = style.align,
        wrap     = style.wrap,
    }

    b^ = {
        id          = make_id(label, parent),
        debug_label = label,
        parent      = parent,
        direction   = direction,
        size_mode   = size_mode,
        w           = w,
        h           = h,
        bounds      = {},
        elements    = nil,
        hidden      = hidden,
        style       = style_with_defaults,
    }

    check_box_sizing(b)

    return b
}

text :: proc(content: string, hidden := false, size := _Text_Size, color := _Text_Color, allocator := context.allocator) -> ^Text {
    t := new(Text)
    t^ = { content = content, size = size, color = color, hidden = hidden, icon = false }

    return t
}

icon :: proc(name: string, size := _Text_Size, color := _Text_Color, allocator := context.allocator) -> ^Text {
    ic := new(Text)
    ic^ = { content = name, size = size, color = color, icon = true }

    return ic
}

image :: proc(debug_label: string, texture: any, w, h: f32) -> ^Image {
    i := new(Image)
    i^ = { debug_label = debug_label, texture = texture, bounds = { w, h } }

    return i
}

check_box_sizing :: proc(box: ^Box) {
    if box.size_mode == .Mixed { return }

    if box.w != -1 && (box.w < 0 || box.w > 1) {
        fatal(fmt.tprintf("ERROR: (Box '%s'): Width should be -1 or 0..1, got %f", box.debug_label, box.w))
    }

    if box.h != -1 && (box.h < 0 || box.h > 1) {
        fatal(fmt.tprintf("ERROR: (Box '%s'): Height should be -1 or 0..1, got %f", box.debug_label, box.h))
    }
}

add_elements :: proc(parent: ^Box, elements: ..Element) {
    total : f32 = 0.0
    for el in parent.elements {
        switch n in el {
        case ^Box:
            sz := n.w if parent.direction == .Row else n.h
            if sz >= 0 { total += sz }
        case ^Image:
            sz := n.bounds[0] if parent.direction == .Row else n.bounds[1]
            if sz >= 0 { total += sz }
        case ^Text:
        }
    }

    for el in elements {
        switch n in el {
        case ^Box:
            n.parent = parent
            if n.size_mode == .Relative {
                sz := n.w if parent.direction == .Row else n.h
                if sz >= 0 {
                    total += sz
                    if !parent.style.wrap && !parent.scroll.enabled && total > 1.0 {
                        fatal(
                            fmt.tprintf("ERROR: LX: (Box '%s'): children exceed 1.0, got %.2f, '%s' pushed it over by '%.2f'",
                                n.parent.debug_label, total, n.debug_label, (total - 1.0),
                            ),
                        )
                    }
                }
            }
        case ^Image:
        case ^Text:
        }

        append(&parent.elements, el)
    }
}

cross_align_offset :: proc(align: Alignment, avail_cross, child_cross: f32) -> f32 {
    switch align {
    case .Start:  return 0
    case .Center: return (avail_cross - child_cross) / 2
    case .End:    return avail_cross - child_cross
    }
    return 0
}

// Implementation "repurposed" from clay
//  https://github.com/nicbarker/clay
layout :: proc(b: ^Box, parent_rect: Rect, ctx: ^Context) {
    b.bounds = parent_rect

    if b.style.round > 0 {
        smaller := min(parent_rect.w, parent_rect.h)
        b.style.round = b.style.round / smaller if smaller > 0 else 0
    }

    pad := f32(b.style.padding)
    content_x   := parent_rect.x + pad
    content_y   := parent_rect.y + pad
    available_w := parent_rect.w - pad * 2
    available_h := parent_rect.h - pad * 2

    is_row := b.direction == .Row

    // Reduce available to shift scrollbar off the contents
    if b.scroll.enabled {
        if is_row { available_h -= _Scrollbar_Size } else { available_w -= _Scrollbar_Size }
    }

    // Don't pre-subtract total gap for wrapping rows, gaps are handled per-line
    if !(is_row && b.style.wrap) {
        total_gap := f32(b.style.gap * (len(b.elements) - 1))
        if is_row { available_w -= total_gap } else { available_h -= total_gap }
    }

    avail_main  := available_w if is_row else available_h
    avail_cross := available_h if is_row else available_w

    // First pass: compute sizes for fixed children, count growers
    used_main : f32 = 0
    grow_count : int = 0
    for &element in b.elements {
        switch el in element {
        case ^Box:
            main_frac  := el.w if is_row else el.h
            cross_frac := el.h if is_row else el.w

            if el.size_mode == .Mixed {
                if is_row { el.bounds.w = el.w; el.bounds.h = el.h } else { el.bounds.w = el.w; el.bounds.h = el.h }
                if cross_frac == -1 {
                    if is_row { el.bounds.h = available_h } else { el.bounds.w = available_w }
                }
                if main_frac == -1 {
                    grow_count += 1
                } else {
                    used_main += el.bounds.w if is_row else el.bounds.h
                }
            } else {
                if main_frac == -1 {
                    grow_count += 1
                } else {
                    if is_row { el.bounds.w = main_frac * available_w } else { el.bounds.h = main_frac * available_h }
                    used_main += el.bounds.w if is_row else el.bounds.h
                }

                if cross_frac == -1 {
                    if is_row { el.bounds.h = available_h } else { el.bounds.w = available_w }
                } else {
                    if is_row { el.bounds.h = cross_frac * available_h } else { el.bounds.w = cross_frac * available_w }
                }
            }
        case ^Text:
            if ctx != nil && ctx.measure_text != nil {
                el.bounds = ctx.measure_text(el, ctx)
            } else {
                el.bounds = { el.size, el.size }
            }
            used_main += el.bounds[0] if is_row else el.bounds[1]
        case ^Image:
            used_main += el.bounds[0] if is_row else el.bounds[1]
        }
    }

    // Distribute remaining space to grow children
    if grow_count > 0 {
        remaining := max(avail_main - used_main, 0) / f32(grow_count)
        for &element in b.elements {
            switch el in element {
            case ^Box:
                main_frac := el.w if is_row else el.h
                if main_frac == -1 {
                    if is_row { el.bounds.w = remaining } else { el.bounds.h = remaining }
                }
            case ^Text:
            case ^Image:
            }
        }
    }

    if is_row && b.style.wrap {
        gap := f32(b.style.gap)
        cursor_x := content_x
        cursor_y := content_y
        line_height : f32 = 0

        for &element in b.elements {
            child_w, child_h : f32

            switch el in element {
            case ^Box:   child_w = el.bounds.w; child_h = el.bounds.h
            case ^Text:  child_w = el.bounds[0]; child_h = el.bounds[1]
            case ^Image: child_w = el.bounds[0]; child_h = el.bounds[1]
            }

            // Wrap to next line if this child overflows
            if cursor_x + child_w > content_x + available_w && cursor_x > content_x {
                cursor_x = content_x
                cursor_y += line_height + gap
                line_height = 0
            }

            switch el in element {
            case ^Box:
                el.bounds.x = cursor_x
                el.bounds.y = cursor_y
                layout(el, el.bounds, ctx)
            case ^Text:
                el.pos = { cursor_x, cursor_y }
            case ^Image:
                el.pos = { cursor_x, cursor_y }
            }

            cursor_x += child_w + gap
            line_height = max(line_height, child_h)
        }
    } else {
        // Scrollable: compute content size and clamp offset
        if b.scroll.enabled {
            total_gap := f32(b.style.gap * max(len(b.elements) - 1, 0))
            b.scroll.content_size = used_main + total_gap
            max_scroll := max(b.scroll.content_size - avail_main, 0)
            b.scroll.offset = clamp(b.scroll.offset, 0, max_scroll)
        }

        // Justify: offset on main axis (no leftover when growers consumed it)
        main_space := f32(0) if grow_count > 0 else max(avail_main - used_main, 0)
        main_offset : f32 = 0
        switch b.style.justify {
        case .Start:  main_offset = 0
        case .Center: main_offset = main_space / 2
        case .End:    main_offset = main_space
        }

        scroll_offset := b.scroll.offset if b.scroll.enabled else 0
        cursor_main  := (content_x if is_row else content_y) + main_offset - scroll_offset
        cursor_cross := content_y if is_row else content_x

        // Second pass: position children
        for &element, index in b.elements {
            child_main_size, child_cross_size : f32

            switch el in element {
            case ^Box:
                child_main_size  = el.bounds.w if is_row else el.bounds.h
                child_cross_size = el.bounds.h if is_row else el.bounds.w

                co := cross_align_offset(b.style.align, avail_cross, child_cross_size)
                if is_row {
                    el.bounds.x = cursor_main
                    el.bounds.y = cursor_cross + co
                } else {
                    el.bounds.x = cursor_cross + co
                    el.bounds.y = cursor_main
                }
                layout(el, el.bounds, ctx)
            case ^Text:
                child_main_size  = el.bounds.x if is_row else el.bounds.y
                child_cross_size = el.bounds.y if is_row else el.bounds.x

                co := cross_align_offset(b.style.align, avail_cross, child_cross_size)
                if is_row {
                    el.pos = { cursor_main, cursor_cross + co }
                } else {
                    el.pos = { cursor_cross + co, cursor_main }
                }
            case ^Image:
                child_main_size  = el.bounds.x if is_row else el.bounds.y
                child_cross_size = el.bounds.y if is_row else el.bounds.x

                co := cross_align_offset(b.style.align, avail_cross, child_cross_size)
                if is_row {
                    el.pos = { cursor_main, cursor_cross + co }
                } else {
                    el.pos = { cursor_cross + co, cursor_main }
                }
            }

            gap : f32 = 0
            if index != len(b.elements) - 1 { gap = f32(b.style.gap) }
            cursor_main += child_main_size + gap
        }
    }

    if b.parent == nil {
        for _, floater in ctx.floaters {
            layout(floater, floater.parent.bounds, ctx)
        }
    }
}

handle_input :: proc(b: ^Box, ctx: ^Context) {
    ctx.state.hover_id = 0
    if b.hidden { return }

    in_floater := false
    if b.parent == nil {
        for _, floater in ctx.floaters {
            if floater.hidden { continue }
            if point_in_rect(floater.bounds, ctx.state.mouse_pos) {
                in_floater = true
            }
            _handle_input(floater, ctx)
        }
    }

    if !in_floater { _handle_input(b, ctx) }
}

@(private)
_handle_input :: proc(b: ^Box, ctx: ^Context) {
    if b.hidden { return }

    hovered := point_in_rect(b.bounds, ctx.state.mouse_pos)
    if hovered { ctx.state.hover_id = b.id }

    if b.scroll.enabled && hovered {
        is_row := b.direction == .Row
        visible := b.bounds.w if is_row else b.bounds.h
        max_scroll := max(b.scroll.content_size - visible, 0)

        if ctx.state.scroll_wheel != 0 { b.scroll.offset -= ctx.state.scroll_wheel }

        b.scroll.offset = clamp(b.scroll.offset, 0, max_scroll)
        ctx.scroll_offsets[b.id] = b.scroll.offset
    }

    for &element in b.elements {
        switch el in element {
        case ^Box:  _handle_input(el, ctx)
        case ^Text:
        case ^Image:
        }
    }
}

render :: proc(b: ^Box, ctx: ^Context, draw_fn: proc(element: ^Element, ctx: ^Context)) {
    if b.hidden { return }

    root_element := Element(b)
    draw_fn(&root_element, ctx)

    if b.scroll.enabled && ctx.begin_scissor != nil { ctx.begin_scissor(b.bounds) }

    for &element in b.elements {
        switch el in element {
        case ^Box:
            if b.scroll.enabled {
                // Skip drawing items outside the scroll area
                // would be nice to have some way of not actually putting them in the tree
                // when we exceed the bounds, but this cuts us down to 7-11% cpu usage for 200+ buttons
                // being drawn from 15+% which is not much cause if we dont push the list items
                // before layout, we drop to 2-4% which is much better, meaning that
                // the issue is in how we do scrollable items
                //
                // This is more of a band-aid cause we still load 200+ buttons (box+text) in memory
                // but we only ever render whats in the viewport,
                if (el.bounds.y + el.bounds.h) < b.bounds.y { break }
                if el.bounds.y > (b.bounds.h + b.bounds.y)  { break }
            }
            render(el, ctx, draw_fn)
        case ^Text:
            if el.hidden { return }
            draw_fn(&element, ctx)
        case ^Image:
            draw_fn(&element, ctx)
        }
    }

    if b.scroll.enabled && ctx.end_scissor != nil { ctx.end_scissor() }

    // Draw scrollbar after scissor so it's not clipped
    if b.scroll.enabled {
        is_row := b.direction == .Row
        visible := b.bounds.w if is_row else b.bounds.h
        content := b.scroll.content_size

        if content > visible {
            max_scroll   := content - visible
            thumb_ratio  := visible / content
            track_length := visible

            tc := b.style.track_color if b.style.track_color != {} else _Track_Color
            thc := b.style.thumb_color if b.style.thumb_color != {} else _Thumb_Color

            track: Box
            thumb: Box

            if is_row {
                sx := b.bounds.x
                sy := b.bounds.y + b.bounds.h - _Scrollbar_Size
                track_start := sx

                thumb_w := max(thumb_ratio * track_length, 20)
                thumb_x := track_start + (b.scroll.offset / max_scroll) * (track_length - thumb_w)

                track   = { bounds = { track_start, sy, track_length, _Scrollbar_Size }, style = { bg = tc } }
                thumb   = { bounds = { thumb_x, sy, thumb_w, _Scrollbar_Size }, style = { bg = thc, round = _Scrollthumb_Round } }
            } else {
                sx := b.bounds.x + b.bounds.w - _Scrollbar_Size
                sy := b.bounds.y
                track_start := sy

                thumb_h := max(thumb_ratio * track_length, 20)
                thumb_y := track_start + (b.scroll.offset / max_scroll) * (track_length - thumb_h)

                track    = { bounds = { sx, track_start, _Scrollbar_Size, track_length }, style = { bg = tc } }
                thumb    = { bounds = { sx, thumb_y,     _Scrollbar_Size, thumb_h },      style = { bg = thc, round =_Scrollthumb_Round } }
            }

            track_el := Element(&track)
            thumb_el := Element(&thumb)
            draw_fn(&track_el, ctx)
            draw_fn(&thumb_el, ctx)
        }
    }

    if b.parent == nil {
        for _, floater in ctx.floaters {
            render(floater, ctx, draw_fn)
        }
    }
}

get_heirarchy :: proc(root: ^Box, allocator := context.temp_allocator) -> string {
    sb := strings.builder_make()

    root_element := Element(root)
    walk_tree(&root_element, &sb)
    return strings.to_string(sb)
}

walk_tree :: proc(element: ^Element, sb: ^strings.Builder, depth := 0) {
    strings.write_string(sb, write_element(element, depth))
    switch &elem in element {
    case ^Box:
        for &child_elem in elem.elements {
            walk_tree(&child_elem, sb, depth + 1)
        }
    // always leaf nodes
    case ^Text:
    case ^Image:
    }
}

write_element :: proc(element: ^Element, depth := 0) -> string {
    string_el := ""
    switch el in element {
    case ^Box:
        string_el = fmt.aprintfln(
            "%*sBox(id=%d, label=%s, direction=%v, width=%f, height=%f, size_mode=%v)",
            depth * 2, "", el.id, el.debug_label, el.direction, el.w, el.h, el.size_mode,
        )
    case ^Text:
        string_el = fmt.aprintfln(
            "%*sText(size=%f, color=%v, pos=%v, hidden=%v, content=\"%s\")",
            depth * 2, "", el.size, el.color, el.pos, el.hidden, el.content,
        )
    case ^Image:
        string_el = fmt.aprintfln(
            "%*sImage(label=%s pos=%v, bounds=%v)",
            depth * 2, "", el.debug_label, el.pos, el.bounds,
        )

    }

    return string_el
}

fatal :: proc(message: string) {
    fmt.eprintln(message)
    os.exit(1)
}
