# lx

A simple UI layout library inspired by [clay](https://github.com/nicbarker/clay).

## Usage

Vendor it into your project:

## Core Concepts

### Elements

lx has three element types (as of now) that can be composed together:

- **Box** — the core container. Holds other elements, controls layout direction, sizing, styling and scrolling.
- **Text** — a text or icon label.
- **Image** — a textured image.


### Boxes

Create a box with `lx.box`:


**Size modes:**

| Mode        | Behaviour                                                                                                           |
| ------      | -----------                                                                                                         |
| `.Relative` | `w`/`h` are fractions of the parent (0..1). `-1` means fill remaining space.                                        |
| `.Mixed`    | One axis is a fixed pixel value, the other is relative or both are fixed. Useful for e.g. fixed height, fill width. |

**Direction** controls how children are laid out:
- `.Row` — left to right
- `.Col` — top to bottom


### Building a layout

```odin
root := lx.box("root", 1, 1, .Col, style = { bg = { 30, 30, 30, 255 }, padding = 10, gap = 5 })

header := lx.box("header", -1, 0.1, style = { bg = { 60, 60, 80, 255 }, align = .Center })
lx.add_elements(header, lx.text("Hello lx", size = 30))

content := lx.box("content", -1, -1, style = { bg = { 50, 50, 50, 255 } })

lx.add_elements(root, header, content)
```

Then run layout to compute positions and bounds:

```odin
lx.layout(root, { 0, 0, f32(screen_w), f32(screen_h) }, ctx)
```

### Scrollable Areas

Use `lx.scroll_area` to create a box whose children can scroll:

```odin
list := lx.scroll_area("my-list", -1, 0.8, direction = .Col, style = { gap = 5 })

for i in 0..<50 {
    item := lx.box(fmt.tprintf("item-%d", i), -1, 40, size_mode = .Mixed, style = { bg = { 80, 80, 80, 255 } })
    lx.add_elements(list, item)
}
```

For horizontal scrolling pass `direction = .Row` and use `.Mixed` sizing on children with a fixed width.


### Rendering

lx is renderer-agnostic. You provide a `draw_fn` that receives each element and draws it however you like:

```odin
lx.render(root, ctx, proc(element: ^lx.Element, ctx: ^lx.Context) {
    switch el in element {
    case ^lx.Box:
        // draw el.bounds with el.style.bg, el.style.round etc.
    case ^lx.Text:
        // draw el.content at el.pos with el.size, el.color
    case ^lx.Image:
        // draw el.texture at el.pos with el.bounds
    }
})
```

### Input

Call `lx.handle_input` each frame before rendering to update hover state and process scroll wheel input:

```odin
lx.handle_input(root, ctx)
```

The `Context` provides mouse position, scroll delta, and hooks for scissor clipping (needed for scroll areas):

```odin
ctx := lx.Context{
    font          = { text = my_font, icon = my_icon_font },
    measure_text  = my_measure_text_proc,
    begin_scissor = my_begin_scissor_proc,
    end_scissor   = my_end_scissor_proc,
    state = {
        mouse_pos    = { mouse_x, mouse_y },
        scroll_wheel = scroll_delta,
    },
}
```

---

### Debug

Print the element tree for any box:

```odin
fmt.println(lx.get_heirarchy(root))
```

## Examples

See the [`examples`](https://github.com/musaubrian/simp) for working examples.
