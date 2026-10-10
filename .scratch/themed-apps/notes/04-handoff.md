# Ticket 02 -> ticket 04 handoff

Ticket 04 owns the user docs. Two findings from ticket 02 must land in
`docs/user/theme-desktop-setup.md`.

## 1. Disclosure: upstream debug placeholders survive the override

Any `:root` namespace override leaves the base theme's literal debug values in
place, because they are not derived from the palette variables we set. In the
built `midnight.css`
(`https://refact0r.github.io/midnight-discord/build/midnight.css`, sha256
`928fe2279f44c1c3d44baf7e940a67c28731dbc6088c778a77a935a49036b2e2`), inside the
`@container root style(--colors: on)` block, the button-state examples are:

```
--button-danger-background-disabled: lime;
--button-outline-brand-background-hover: blue;
--button-outline-brand-border-active: magenta;
```

Document these as a known cosmetic limit: a disabled danger button, and the
outline-brand hover/active states, keep the upstream bright debug colors.

Caution for the doc author: these three are the *button* examples, not the
only ones. The same active `lime`/`magenta`/`blue` debug pattern repeats 84
times across midnight's Discord namespace (cards, chips, checkboxes, expressive
gradients, panels, and so on). A live button/UI sweep should expect more
unthemed accents than just these three, and the wording should call the debug
placeholders a known upstream artifact rather than claim none remain.

## 2. Needs a live check: light-mode accent-ladder link contrast

The `--purple-*` ladder is built as `color-mix(in srgb, accent <pct%>,
bright_foreground)`, and system24 drives links and hover borders from it
(`--accent-1: var(--purple-1)`, `--border-hover: var(--accent-2)`). On a light
palette the mix drifts the accent toward white, so links lose contrast against
a light background. Measured against the ticket's own light fixture
(`background #f5f5f5`, `accent #7aa2f7`, `bright_foreground #ffffff`):

```
--purple-1 #b6ccfb   1.48:1   (--accent-1 = link color)
--purple-2 #a2bef9   1.71:1
--purple-3 #92b3f8   1.92:1
--purple-4 #85a9f8   2.13:1
--purple-5 #7aa2f7   2.31:1
```

All five are far below the 4.5:1 body-text threshold, and the ladder only gets
lighter as it goes to `--purple-1`. The test's text-ramp contrast check does not
cover this because it validates `--text-1..5`, not the accent ladder. Flag this
for a live look in Discord on a light theme: links, hover borders, and accent
buttons may be hard to read, and the fix may need to mix toward the mode's
background ink (or a darker step) for light palettes rather than always toward
`bright_foreground`.
