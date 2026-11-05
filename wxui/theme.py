import os
import sys

import wx


def _assets_dir() -> str:
    """Directory holding the bundled ``assets`` (cover art and icons)."""
    if getattr(sys, "frozen", False) and sys.platform == "darwin":
        # py2app keeps data files in Contents/Resources/, not next to the
        # bundled modules (Contents/Resources/lib/python3.12/...).
        return os.path.join(
            os.path.dirname(os.path.dirname(sys.executable)), "Resources", "assets"
        )
    # Source checkout and PyInstaller builds (which unpack modules and data
    # into the same directory tree).
    return os.path.join(
        os.path.dirname(os.path.dirname(os.path.realpath(__file__))), "assets"
    )


ASSETS_DIR = _assets_dir()
DEFAULT_COVER = os.path.join(ASSETS_DIR, "doom-cacodemon.png")
APP_ICON = os.path.join(ASSETS_DIR, "pyzdl-launcher.png")


def font(size_delta: int = 0, bold: bool = False) -> wx.Font:
    value = wx.Font(wx.SystemSettings.GetFont(wx.SYS_DEFAULT_GUI_FONT))
    if size_delta:
        value.SetPointSize(max(8, value.GetPointSize() + size_delta))
    if bold:
        value = value.Bold()
    return value


def heading_font() -> wx.Font:
    return font(4, bold=True)


def title_font() -> wx.Font:
    return font(9, bold=True)


def mono_font() -> wx.Font:
    value = wx.Font(wx.FontInfo(10).Family(wx.FONTFAMILY_TELETYPE))
    return value


def bitmap_from_path(path: str, max_size: tuple[int, int]) -> wx.Bitmap:
    """Load an image and scale it to fit inside max_size, preserving aspect."""
    width, height = max_size
    if not path or not os.path.isfile(path):
        path = DEFAULT_COVER
    image = wx.Image(path, wx.BITMAP_TYPE_ANY)
    if not image.IsOk():
        image = wx.Image(DEFAULT_COVER, wx.BITMAP_TYPE_ANY)
    if not image.IsOk():
        return wx.Bitmap(width, height)
    image_width, image_height = image.GetWidth(), image.GetHeight()
    if image_width <= 0 or image_height <= 0:
        return wx.Bitmap(width, height)
    scale = min(width / image_width, height / image_height)
    new_size = (max(1, int(image_width * scale)), max(1, int(image_height * scale)))
    if new_size != (image_width, image_height):
        image = image.Scale(new_size[0], new_size[1], wx.IMAGE_QUALITY_HIGH)
    bitmap = wx.Bitmap(image)
    # Centre the image on a canvas matching the window background so the
    # layout stays stable without painting a black box behind transparent art.
    canvas = wx.Bitmap(width, height)
    dc = wx.MemoryDC(canvas)
    dc.SetBackground(wx.Brush(wx.SystemSettings.GetColour(wx.SYS_COLOUR_WINDOW)))
    dc.Clear()
    dc.DrawBitmap(bitmap, (width - new_size[0]) // 2, (height - new_size[1]) // 2, True)
    dc.SelectObject(wx.NullBitmap)
    return canvas


def cover_bitmap(profile, size=(150, 190)) -> wx.Bitmap:
    image = profile.image or profile.get_cover_art()
    return bitmap_from_path(image.resolved_path if image else DEFAULT_COVER, size)


def small_icon(profile=None) -> wx.Bitmap:
    image = profile.image or profile.get_cover_art() if profile else None
    return bitmap_from_path(image.resolved_path if image else DEFAULT_COVER, (24, 24))


def app_icon() -> wx.Icon:
    if os.path.isfile(APP_ICON):
        return wx.Icon(APP_ICON, wx.BITMAP_TYPE_PNG)
    return wx.Icon()
