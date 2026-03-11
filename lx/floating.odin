package lx

import "core:fmt"

dialog :: proc(label: string, w, h: f32, visible: ^bool, anchor: ^Box, show_close := true, direction: Direction = .Col, ctx: ^Context, style := Style{}) -> ^Box {
    dialog_container_style := Style{
        bg =    style.bg if style.bg != {} else _Default_Bg,
        justify = .Start,
        align = .Start,
        padding = 1,
        round = style.round,
    }

    dialog_style := style
    dialog_style.bg = {}
    dialog_style.round = 0

    overlay := box(fmt.tprintf("%s-label", label), 1, 1, .Col, .Relative, hidden = !visible^, parent = anchor, style = {
        bg      = { style.bg.r, style.bg.g, style.bg.b, style.bg.a / 10 },
        align   = .Center,
        justify = .Center,
    })

    dialog_container := box(label, w, h, .Col, .Relative, style = dialog_container_style, parent = overlay)
    header := box(fmt.tprintf("%s-header", label), -1, 0.1, style = { align = .Start, justify = .End, padding = 1 })
    if show_close {
        if icon_button(header, ICON_X, 40, 40, 20, ctx = ctx) { visible^ = false }
        add_elements(dialog_container, header)
    }

    dialog_contents := box(label, -1, -1, .Col, .Relative, style = dialog_style, parent = dialog_container)

    add_elements(dialog_container, dialog_contents)
    add_elements(overlay, dialog_container)

    ctx.floaters[overlay.id] = overlay

    return dialog_contents
}
