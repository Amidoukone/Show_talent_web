"""One-off script: derive icon-only / white / app-icon variants from
assets/logo.png (black ink on white, full "AD FOOT" lockup).
Not wired into the build; re-run manually if the source logo changes.
"""
from PIL import Image, ImageOps

BASE = r"C:\Users\Ing.Amidou.KONE\Desktop\MyApp\show_talent - web"
SRC = BASE + r"\assets\logo.png"

BG = (14, 17, 20)  # AdminTheme.background 0xFF0E1114

# Pixel bounds found by scanning the source (ink = luminance < 200).
ICON_BOX = (203, 102, 1026 + 1, 896 + 1)  # left, top, right, bottom
FULL_BOX = (48, 102, 1192 + 1, 1104 + 1)


def load_masks():
    gray = Image.open(SRC).convert("L")
    alpha = ImageOps.invert(gray)  # ink -> opaque, white bg -> transparent
    return gray.size, alpha


def make_rgba(alpha, size, color):
    solid = Image.new("RGB", size, color)
    return Image.merge("RGBA", (*solid.split(), alpha))


def pad_to_square(img, margin_ratio=0.08):
    w, h = img.size
    side = max(w, h)
    margin = int(side * margin_ratio)
    canvas_side = side + margin * 2
    canvas = Image.new("RGBA", (canvas_side, canvas_side), (0, 0, 0, 0))
    canvas.paste(img, ((canvas_side - w) // 2, (canvas_side - h) // 2), img)
    return canvas


def app_icon(icon_rgba_white, size, safe_ratio):
    canvas = Image.new("RGBA", (size, size), (*BG, 255))
    target = int(size * safe_ratio)
    resized = icon_rgba_white.resize((target, target), Image.LANCZOS)
    canvas.alpha_composite(
        resized, ((size - target) // 2, (size - target) // 2)
    )
    return canvas.convert("RGBA")


def main():
    size, alpha = load_masks()

    black_full = make_rgba(alpha, size, (0, 0, 0))
    white_full = make_rgba(alpha, size, (255, 255, 255))

    icon_black = pad_to_square(black_full.crop(ICON_BOX))
    icon_white = pad_to_square(white_full.crop(ICON_BOX))
    lockup_white = white_full.crop(FULL_BOX)

    icon_black.save(BASE + r"\assets\logo_icon.png")
    icon_white.save(BASE + r"\assets\logo_icon_white.png")
    lockup_white.save(BASE + r"\assets\logo_white.png")

    app_icon(icon_white, 64, 0.8).save(BASE + r"\web\favicon.png")
    app_icon(icon_white, 192, 0.72).convert("RGB").save(
        BASE + r"\web\icons\Icon-192.png"
    )
    app_icon(icon_white, 512, 0.72).convert("RGB").save(
        BASE + r"\web\icons\Icon-512.png"
    )
    app_icon(icon_white, 192, 0.62).save(
        BASE + r"\web\icons\Icon-maskable-192.png"
    )
    app_icon(icon_white, 512, 0.62).save(
        BASE + r"\web\icons\Icon-maskable-512.png"
    )

    print("Done:")
    print(" icon_black:", icon_black.size)
    print(" icon_white:", icon_white.size)
    print(" lockup_white:", lockup_white.size)


if __name__ == "__main__":
    main()
