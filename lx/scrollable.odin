package lx

scroll_area :: proc(label: string, w, h: f32, direction: Direction = .Col, style := Style{}, ctx: ^Context = nil, allocator := context.allocator) -> ^Box {
    b := box(label, w, h, direction, style = style, allocator = allocator)
    b.scroll.enabled = true
    if ctx != nil {
        if offset, ok := ctx.scroll_offsets[b.id]; ok {
            b.scroll.offset = offset
        }
    }
    return b
}
