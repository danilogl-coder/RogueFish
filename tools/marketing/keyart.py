"""Key art: a legendary goldfish facing a charging megalodon, with the
ocean's cast around them. Composed at native pixel size, exported in the
formats a launch needs (16:9 hero, 1:1 post, 9:16 story, X/Twitter header,
YouTube thumbnail), with and without the logo."""
from common import *


def kelp_frame(im, side, seed=7):
    """Dark foreground kelp silhouettes framing one edge (depth)."""
    rnd = random.Random(seed + side)
    d = ImageDraw.Draw(im)
    w, h = im.size
    for i in range(3):
        x0 = (6 + i * 9 + rnd.randint(-3, 3)) if side == 0 else (w - 6 - i * 9 + rnd.randint(-3, 3))
        top = int(h * rnd.uniform(0.15, 0.45))
        for y in range(top, h):
            u = (y - top) / (h - top)
            x = x0 + 4 * math.sin(y / 11.0 + i) * (1 - u)
            wd = 2 + int(u * 2)
            d.line([(x - wd, y), (x + wd, y)], fill=(4, 18, 28, 235))
            if y % 9 == 0:
                sgn = 1 if (y // 9) % 2 else -1
                d.line([(x, y), (x + sgn * 6, y - 4)], fill=(4, 18, 28, 235), width=2)


def vignette(im, strength=150):
    w, h = im.size
    v = Image.new("RGBA", (w, h))
    px = v.load()
    for y in range(h):
        for x in range(w):
            dx, dy = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
            r = min(1.0, math.hypot(dx * 0.8, dy * 0.9))
            a = int(strength * max(0.0, r - 0.7) / 0.3)
            px[x, y] = (2, 8, 20, (a // 40) * 40)
    im.alpha_composite(v)


def glow(im, x, y, r, col=(120, 230, 255)):
    g = Image.new("RGBA", im.size)
    d = ImageDraw.Draw(g)
    for i, a in ((1.0, 18), (0.72, 26), (0.45, 34)):
        d.ellipse([x - r * i, y - r * i * 0.8, x + r * i, y + r * i * 0.8], fill=col + (a,))
    im.alpha_composite(g)


def cast_scene(w, h, focus_x, seed=3, bed=None):
    im = ocean(w, h, seed)
    rnd = random.Random(seed)
    # far silhouettes: a crop of the game's far background layer
    far = sheet_frame("env/bg_far")
    for x in range(0, w, far.width):
        paste(im, far, x, h - far.height - (bed or 20) + 24, "tl")
    seabed(im, h - (bed or 20), seed)
    # schools and bystanders
    for i in range(16):
        s = sheet_frame("creatures/sardine", rnd.randrange(6))
        wide = w > h * 1.4
        paste(im, s, w * (0.62 if wide else 0.6) + rnd.randint(-40, 40), h * (0.16 if wide else 0.4) + rnd.randint(-12, 14))
    for jx, jy in ((0.9, 0.12), (0.5, 0.2)):
        j = sheet_frame("creatures/jellyfish", rnd.randrange(4))
        paste(im, j, w * jx, h * jy)
    t = sheet_frame("creatures/turtle", 1)
    paste(im, flip(t), w * 0.12, h * 0.62)
    for i in range(4):
        p = flip(sheet_frame("creatures/piranha", rnd.randrange(6)))
        paste(im, p, w * 0.08 + rnd.randint(0, 60), h * 0.8 - rnd.randint(0, 30))
    bubbles(im, w // 14, seed + 1)
    return im


def hero(w, h, k, with_logo, name, px, py, mx, my, logo_xy=None, tag=True, logo_w=None):
    im = cast_scene(w, h, px)
    meg = flip(sheet_frame("creatures/megalodon", 2))
    paste(im, meg, mx, my)
    fish = trim(player_frame("dourado", 4, 2))
    glow(im, px + 6, py, fish.width * 0.75)
    paste(im, fish, px, py)
    bubbles(im, 8, 11, (int(px + fish.width * 0.3), int(py - 30), int(px + fish.width * 0.6), int(py - 6)))
    kelp_frame(im, 0)
    kelp_frame(im, 1)
    vignette(im)
    big = up(im, k)
    if with_logo:
        lg = logo(logo_w or int(big.width * 0.34))
        lx, ly = logo_xy or (int(big.width * 0.04), int(big.height * 0.05))
        big.alpha_composite(lg, (lx, ly))
        if tag:
            text(big, "LARVA TO LEGEND", lx + lg.width / 2, ly + lg.height + k * 3, max(16, lg.width // 16), outline=3)
    big.convert("RGB").save(os.path.join(OUT, name))
    return big


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    # 16:9 hero (1920x1080)
    hero(480, 270, 4, True, "keyart_1920x1080.png", 150, 150, 370, 140)
    hero(480, 270, 4, False, "keyart_1920x1080_nologo.png", 150, 150, 370, 140)
    # 1:1 post (1080x1080)
    hero(360, 360, 3, True, "keyart_1080x1080.png", 105, 250, 262, 228, logo_xy=(60, 45), logo_w=600)
    # 9:16 story / TikTok cover (1080x1920)
    hero(270, 480, 4, True, "keyart_1080x1920.png", 110, 385, 160, 250, logo_xy=(90, 110), logo_w=900)
    # X / Twitter header (1500x500) and YouTube thumbnail (1280x720)
    hero(500, 166, 3, True, "header_1500x500.png", 250, 95, 420, 80, logo_xy=(60, 60), tag=False, logo_w=480)
    hero(320, 180, 4, True, "youtube_thumb_1280x720.png", 95, 110, 245, 100, logo_xy=(40, 30), logo_w=560)
    print("ok")
