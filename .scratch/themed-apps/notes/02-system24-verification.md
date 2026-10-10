# Ticket 02: built system24.css derived-variable verification

Date: 2026-10-10. Cross-check for review finding M2.

## What was checked

The local wrapper `~/.config/Vencord/themes/system24.theme.css` is only the
theme's config file; it `@import`s the compiled theme over the network at:

- `https://refact0r.github.io/system24/build/system24.css`
  - sha256 `40c4a111c379d0e438ae7883b0b2e24df98f0d18cd5d9733ae3a4a56c71ba51c`
  - 703 lines, 23458 bytes
- which itself `@import`s `https://refact0r.github.io/midnight-discord/build/midnight.css`
  - sha256 `928fe2279f44c1c3d44baf7e940a67c28731dbc6088c778a77a935a49036b2e2`
  - 2392 lines

Both were downloaded with `curl` into a fresh temp directory
(`/tmp/opencode/system24-verify-*/`), inspected as text only. Nothing from the
files was executed. The build was fetched 2026-10-10. The built
`system24.css` `:root` block is byte-identical to the local wrapper's `:root`
(`diff` clean), so the wrapper's namespace is not stale; the only wrapper
addition is a separate `:root { --online-mobile: var(--purple-2); }` block that
is **absent from both built files** (it is a user-config variable).

## Result (one paragraph)

The ticket's derived-variable claims largely hold, with two wording caveats.
Against the built `system24.css`, the literal `:root` **base** set is
`--colors`, `--bg-1..4`, `--text-1..5`, `--hover`, `--active`, `--active-2`,
`--button-border`, and the five hue scales `--red/green/blue/yellow/purple-1..5`
(39 variables); the **derived** set is `--text-0` (`var(--bg-4)`),
`--message-hover` (`var(--hover)`), `--accent-1..5` (`var(--purple-*)`),
`--accent-new` (`var(--red-2)`), `--mention`/`--mention-hover`
(gradients over `--accent-2`), `--reply`/`--reply-hover`, the status set
`--online/--dnd/--idle/--streaming/--offline`, and `--border-light`/`--border`/
`--border-hover` (20 variables). Our template sets 36 variables: 35 are base,
and the one non-base, `--text-0`, is the ticket's deliberate and required
override (its derived default `var(--bg-4)` is confirmed to chain into
`--white` and `--white-500` inside midnight.css's `@container root
style(--colors: on)` block, so leaving it derived would paint "white" icons and
badges with the main background). Two of the ticket's forbidden variables
`--hover`, `--active`, `--active-2`, `--button-border` are actually literal
**base** values, not derived as the criterion-2 prose implies; the template
still (and correctly) leaves them at the theme's neutral translucent defaults,
so the outcome is unchanged. No template or `EXPECTED` change was warranted.

## Base variables (literal on the theme's `:root`)

```
--colors
--bg-1 --bg-2 --bg-3 --bg-4
--text-1 --text-2 --text-3 --text-4 --text-5
--hover --active --active-2
--button-border
--red-1..5 --green-1..5 --blue-1..5 --yellow-1..5 --purple-1..5
```

## Derived variables (`var()` of base vars)

```
--text-0            var(--bg-4)
--message-hover     var(--hover)
--accent-1..5       var(--purple-1..5)
--accent-new        var(--red-2)
--mention           gradient over var(--accent-2)
--mention-hover     gradient over var(--accent-2)
--reply             gradient over var(--text-3)
--reply-hover       gradient over var(--text-3)
--online            var(--green-2)
--dnd               var(--red-2)
--idle              var(--yellow-2)
--streaming         var(--purple-2)
--offline           var(--text-4)
--border-light      var(--hover)
--border            var(--active)
--border-hover      var(--accent-2)
```

## Template set against the build

`assets/templates/vencord-theme.css` declares exactly the ticket's criterion 2
set (`scripts/test-panel-logic.sh` `EXPECTED`): `--colors`, `--bg-1..4`,
`--text-0..5`, and the five hue scales. Every one is a real `:root` variable of
the built theme (none is absent), 35/36 are literal base, and only `--text-0`
is derived (intentionally overridden).

## Forbidden set against the build

The test's `FORBIDDEN` pattern matches these variables in the built `:root`:
`--mention`, `--mention-hover`, `--accent-1..5`, `--accent-new`, `--border`,
`--border-hover`, `--border-light`, `--message-hover`, `--online`, `--hover`,
`--active`, `--active-2`, `--button-border`. Of those, all but `--hover`,
`--active`, `--active-2`, and `--button-border` are genuinely derived. The
four exceptions are literal base values in the built theme, so the ticket's
"system24 derives those from the base variables" wording is imprecise for them.
The template sets none of the forbidden variables, so behavior is unaffected;
the neutral overlay defaults are a valid choice and need no change.

`--online-mobile` is not defined in either built file at all; the ticket forbids
setting it because the local wrapper derives it (`var(--purple-2)`), and our
template correctly leaves it alone so it keeps tracking `--purple-2`.
