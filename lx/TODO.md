- [ ] TODO(b93313b039ff) :: Make scrollbars clickable/draggable

- [ ] TODO(a0729c817644) :: Less dumb scrolling
Skip drawing items outside the scroll area
would be nice to have some way of not actually putting them in the tree
when we exceed the bounds, but this cuts us down to 7-11% cpu usage for 200+ buttons
being drawn from 15+% which is not much cause if we dont push the list items
before layout, we drop to 2-4% which is much better, meaning that
the issue is in how we do scrollable items

This is more of a band-aid cause we still load 200+ buttons (box+text) in memory
but we only ever render whats in the viewport,
