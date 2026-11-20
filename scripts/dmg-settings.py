# dmgbuild settings for the macOS disk image; scripts/make-dmg.sh passes the
# paths in as defines. The window size and icon positions must match the
# artwork in scripts/dmg-art.swift, which puts the app on the icon's green
# dot and the Applications alias on its pink one.
import os.path

app = defines["app"]  # noqa: F821 (dmgbuild provides `defines`)
art = defines["art"]  # noqa: F821

format = "UDZO"
filesystem = "HFS+"
files = [app, os.path.join(art, "Applications")]
icon = os.path.join(app, "Contents", "Resources", "AppIcon.icns")
background = os.path.join(art, "background.png")  # and background@2x.png

window_rect = ((200, 200), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128
# The largest Finder allows; the labels sit on light plates in the artwork.
text_size = 16
icon_locations = {
    os.path.basename(app): (115, 155),
    "Applications": (525, 155),
    # Hidden files only show on Macs set to show them; keep them out of the
    # way there, past the window's right edge.
    ".background.tiff": (900, 100),
    ".VolumeIcon.icns": (900, 260),
}
hide_extensions = [os.path.basename(app)]
