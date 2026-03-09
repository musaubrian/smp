package lx

Icon_Align :: enum { Start, End }

Button_Style :: struct {
    bg         : Color,
    round      : f32,
    padding    : int,
    icon_align : Icon_Align,
    icon_color : Color,
}

button :: proc(parent: ^Box, label: string, w, h: f32, ctx: ^Context, size_mode: Size_Mode = .Relative, justify : Alignment = .Center, style : Button_Style = {}) -> bool {
    button_style_with_defaults := Style{
        align    = .Center,
        justify  = justify,
        bg       = style.bg,
        hover_bg = { style.bg.r, style.bg.g, style.bg.b, style.bg.a / 2 },
        round    = style.round if style.round > 0 else 5,
        padding  = style.padding,
    }
    base := box(label, w, h, parent = parent, size_mode = size_mode, style = button_style_with_defaults)
    txt := text(label)
    add_elements(base, txt)
    add_elements(parent, base)

    return _button_interaction(base, ctx)
}

icon_button :: proc(parent: ^Box, icon_name: string, w, h : f32, size: i32 = 15, ctx: ^Context, style : Button_Style = {}) -> bool {
    button_style_with_defaults := Style{
        align    = .Center,
        justify  = .Center,
        bg       = style.bg,
        hover_bg = { style.bg.r, style.bg.g, style.bg.b, style.bg.a / 2 },
        round    = style.round if style.round > 0 else 5,
    }

    base := box("icon", w, h, parent = parent, size_mode = .Mixed, style = button_style_with_defaults)
    icon_color := style.icon_color if style.icon_color != {} else _Text_Color
    icon_text := icon(icon_name, size = f32(size), color = icon_color)
    add_elements(base, icon_text)
    add_elements(parent, base)

    return _button_interaction(base, ctx)
}

icon_text_button :: proc(parent: ^Box, label: string, w, h: f32, icon_name: string, size: i32 = 15, ctx: ^Context, size_mode: Size_Mode = .Relative, style : Button_Style = {}) -> bool {
    button_style_with_defaults := Style{
        align    = .Center,
        justify  = .Center,
        bg       = style.bg,
        hover_bg = { style.bg.r, style.bg.g, style.bg.b, style.bg.a / 2 },
        round    = style.round if style.round > 0 else 5,
        gap      = 5,
    }
    base := box(label, w, h, parent = parent, size_mode = size_mode, style = button_style_with_defaults)
    icon_color := style.icon_color if style.icon_color != {} else _Text_Color
    icon := icon(icon_name, size = f32(size), color = icon_color)
    txt := text(label)

    if style.icon_align == .End {
        add_elements(base, txt, icon)
    } else {
        add_elements(base, icon, txt)
    }
    add_elements(parent, base)

    return _button_interaction(base, ctx)
}

@(private)
_button_interaction :: proc(base: ^Box, ctx: ^Context) -> bool {
    hovered := ctx.state.hover_id == base.id
    if hovered && ctx.state.mouse_down { ctx.state.active_id = base.id }

    // Clear active if released outside
    if ctx.state.active_id == base.id && !ctx.state.mouse_down && !hovered { ctx.state.active_id = 0 }

    clicked := ctx.state.active_id == base.id && hovered && !ctx.state.mouse_down
    if clicked { ctx.state.active_id = 0 }

    return clicked
}
