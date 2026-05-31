from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "makau-poke-logo-redrawn.png"


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def centered_text(draw, box, text, font_obj, fill):
    left, top, right, bottom = box
    bbox = draw.textbbox((0, 0), text, font=font_obj)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    x = left + (right - left - width) / 2
    y = top + (bottom - top - height) / 2 - bbox[1]
    draw.text((x, y), text, font=font_obj, fill=fill)


def main():
    scale = 3
    width, height = 1200, 720
    img = Image.new("RGBA", (width, height), (255, 255, 255, 255))
    draw = ImageDraw.Draw(img)

    black = (18, 18, 18, 255)
    orange = (245, 124, 32, 255)
    orange_dark = (181, 78, 20, 255)
    red = (216, 63, 43, 255)
    gray = (88, 88, 88, 255)

    serif = font("C:/Windows/Fonts/georgia.ttf", 210)
    serif_small = font("C:/Windows/Fonts/georgia.ttf", 56)
    sans_bold = font("C:/Windows/Fonts/arialbd.ttf", 34)

    # Fish mark, drawn large so it stays crisp when printed.
    fish = [(414, 58), (724, 181), (432, 304)]
    draw.polygon(fish, fill=orange, outline=black)
    draw.line([(440, 72), (414, 58), (432, 304)], fill=black, width=14, joint="curve")
    draw.line([(724, 181), (432, 304)], fill=black, width=11)
    draw.line([(724, 181), (414, 58)], fill=black, width=11)
    draw.polygon([(732, 181), (814, 118), (795, 181), (814, 244)], fill=(255, 255, 255, 255), outline=orange_dark)
    draw.line([(732, 181), (814, 118)], fill=orange_dark, width=9)
    draw.line([(732, 181), (814, 244)], fill=orange_dark, width=9)
    draw.ellipse((503, 126, 545, 168), fill=black)
    draw.arc((456, 94, 660, 276), 104, 252, fill=(255, 166, 80, 255), width=16)

    # Wordmark.
    draw.text((70, 292), "Makau", font=serif, fill=black)
    draw.text((864, 451), "POKE", font=serif_small, fill=gray)

    # Red descriptor tag.
    tag = (74, 574, 506, 626)
    draw.rounded_rectangle(tag, radius=4, fill=red)
    centered_text(draw, tag, "HAWAIIAN SUSHI FOOD", sans_bold, (255, 255, 255, 255))

    # Small baseline accent under POKE.
    draw.line((869, 548, 1042, 548), fill=orange, width=7)

    img = img.resize((width // scale, height // scale), Image.Resampling.LANCZOS)
    img.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
