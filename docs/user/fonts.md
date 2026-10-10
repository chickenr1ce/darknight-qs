# Fonts

The shell names three families:

- **Iosevka** for bar text.
- **Geist** for reading surfaces.
- **GeistMono Nerd Font** for icons.

Without Iosevka or Geist the text falls back to a default face, and the bar
still reads. Without GeistMono Nerd Font, `config/Icons.qml` renders boxes
instead of glyphs, so install it.

`scripts/install.sh` warns about a missing family and names the package for it.
The families and their fallbacks are editable under Settings → Fonts
(`services/FontService.qml`), which writes the three role properties on
`config/Globals.qml`.
