-- Rendered by scripts/render-theme.sh from the active theme palette.
-- Do not edit: the next palette load overwrites this file.
--
-- Load it by adding `require("theme")` at the end of
-- ~/.config/hypr/modules/looks.lua. See docs/theme-desktop-setup.md.
hl.config({
    general = {
        col = {
            active_border = {
                colors = {"rgba({{active_hex}})", "rgba({{active_hex}})"},
                angle = 45
            },
            inactive_border = "rgba({{inactive_hex}})"
        }
    }
})
