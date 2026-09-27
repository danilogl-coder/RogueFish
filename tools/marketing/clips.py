"""Gameplay GIFs, vertical shorts (TikTok / Reels / Shorts) and the Google
Play promo video, cut from Movie Maker PNG recordings of real gameplay
(see /tmp/claude-0/rec.sh: the autopilot plays, Godot records at 30 fps).

Pixel-perfect: frames are 640x360 native and only upscaled by integers.
Vertical: a 216x360 crop around the camera centre (the player) x5 = 1080x1800,
with 60 px bands for the captions and the end card."""
import glob
import sys
import numpy as np
import soundfile as sf
from common import *
from morph import save_gif, save_mp4, frames_for

REC = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-0/-home-user-RogueFish/09a795d3-c3db-5578-9e28-60d83606ee54/scratchpad/mov"
FPS = 30


def seg(clip, t0, t1, step=1):
    fs = sorted(glob.glob(os.path.join(REC, clip, "f*.png")))
    return [Image.open(f).convert("RGBA") for f in fs[int(t0 * FPS):int(t1 * FPS):step]]


def audio(clip, t0, t1):
    d, sr = sf.read(os.path.join(REC, clip, "f.wav"))
    return d[int(t0 * sr):int(t1 * sr)], sr


def fade(a, sr, fin=0.05, fout=0.3):
    a = a.copy()
    n1, n2 = int(fin * sr), int(fout * sr)
    if n1:
        a[:n1] *= np.linspace(0, 1, n1)[:, None]
    if n2:
        a[-n2:] *= np.linspace(1, 0, n2)[:, None]
    return a


def caption(big, lines, y, size, col=GOLD):
    for i, l in enumerate(lines):
        text(big, l, big.width / 2, y + i * int(size * 1.5), size, col=col if i == 0 else CYAN, outline=max(3, size // 8))


_VBG = None


def _vertical_bg():
    """Caption band: pixel ocean with the logo at the bottom of the card."""
    global _VBG
    if _VBG is None:
        bg = up(ocean(216, 384, 21, top=(20, 70, 110), bot=(4, 12, 28), rays=False), 5)
        lg = logo(360)
        bg.alpha_composite(lg, ((1080 - lg.width) // 2, 1920 - lg.height - 30))
        _VBG = bg
    return _VBG


def vertical(frames, captions):
    """captions: list of (t0, t1, [lines]) in seconds, relative to the clip.
    Layout 1080x1920: caption band (300) / gameplay 216x280 native x5 (1400) /
    logo band (220). The gameplay crop skips the HUD bar at the top."""
    out = []
    for i, f in enumerate(frames):
        cx = f.width // 2
        crop = f.crop((cx - 108, 58, cx + 108, 338))
        big = _vertical_bg().copy()
        big.alpha_composite(up(crop, 5), (0, 300))
        d = ImageDraw.Draw(big)
        d.rectangle([0, 296, 1079, 299], fill=GOLD)
        d.rectangle([0, 1700, 1079, 1703], fill=GOLD)
        t = i / FPS
        for t0, t1, lines in captions:
            if t0 <= t < t1:
                caption(big, lines, 80, 56)
        out.append(big.convert("RGB"))
    return out


def landscape(frames, captions, k=3):
    out = []
    for i, f in enumerate(frames):
        big = up(f, k)
        t = i / FPS
        for t0, t1, lines in captions:
            if t0 <= t < t1:
                band = Image.new("RGBA", (big.width, 190), (4, 10, 24, 170))
                big.alpha_composite(band, (0, big.height - 230))
                caption(big, lines, big.height - 205, 56)
        out.append(big.convert("RGB"))
    return out


def end_card(size, seconds, keyart, cta="FREE ON GOOGLE PLAY"):
    im = Image.open(os.path.join(OUT, keyart)).convert("RGBA").resize(size, Image.NEAREST)
    frames = []
    for i in range(int(seconds * FPS)):
        f = im.copy()
        if (i // 12) % 2 == 0 or i > FPS:
            band_h = size[1] // 9
            band = Image.new("RGBA", (size[0], band_h), (4, 10, 24, 200))
            f.alpha_composite(band, (0, size[1] - band_h - size[1] // 20))
            text(f, cta, size[0] / 2, size[1] - band_h - size[1] // 20 + band_h // 3, max(22, size[0] // 30), outline=3)
        frames.append(f.convert("RGB"))
    return frames


def silence(sec, sr=48000):
    return np.zeros((int(sec * sr), 2))


def write(frames, audio_parts, path):
    """Video frames + concatenated audio (written next to it as wav)."""
    wav = path[:-4] + ".wav"
    a = np.concatenate(audio_parts)
    need = int(len(frames) / FPS * 48000)
    a = a[:need] if len(a) >= need else np.concatenate([a, silence((need - len(a)) / 48000)])
    sf.write(wav, a * 0.9, 48000)
    save_mp4(frames, path, FPS, wav, 0.0)
    os.remove(wav)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[2:]) if len(sys.argv) > 2 else {"gif", "short", "promo"}
    # ---------------------------------------------------------- GIFs (2x)
    if "gif" in only:
        for name, clip, t0, t1 in (("gif_swallowed_by_titanacon", "titan", 2.6, 7.2),
                                   ("gif_leviathan_chase", "lev", 15.5, 19.8),
                                   ("gif_kraken_boss", "kraken", 14.5, 18.5),
                                   ("gif_horde_frenzy", "horde", 11.5, 15.5)):
            fr = [up(f, 2).convert("RGB") for f in seg(clip, t0, t1, 2)]
            save_gif(fr, os.path.join(OUT, name + ".gif"), 15)
    # ------------------------------------------------ vertical shorts 9:16
    if "short" in only:
        swallowed = seg("titan", 2.4, 8.2) + seg("titan", 19.4, 22.4)
        v = vertical(swallowed, [(0, 1.8, ["THIS BOSS CAN", "SWALLOW YOU WHOLE"]),
                                 (1.8, 5.8, ["SO YOU FIGHT", "FROM THE INSIDE"]),
                                 (5.8, 9.0, ["...UNTIL IT", "SPITS YOU OUT"])])
        v += end_card((1080, 1920), 2.5, "keyart_1080x1920.png")
        a1, sr = audio("titan", 2.4, 8.2)
        a2, _ = audio("titan", 19.4, 22.4)
        write(v, [fade(a1, sr), fade(a2, sr), silence(2.5)], os.path.join(OUT, "short_swallowed_1080x1920.mp4"))

        bosses = seg("lev", 5.5, 11.0) + seg("kraken", 14.5, 19.5)
        v = vertical(bosses, [(0, 5.5, ["A LEVIATHAN", "HUNTS YOU"]), (5.5, 10.5, ["THEN A KRAKEN", "RISES"])])
        v += end_card((1080, 1920), 2.5, "keyart_1080x1920.png")
        b1, sr = audio("lev", 5.5, 11.0)
        b2, _ = audio("kraken", 14.5, 19.5)
        write(v, [fade(b1, sr), fade(b2, sr), silence(2.5)], os.path.join(OUT, "short_bosses_1080x1920.mp4"))

        horde = seg("horde", 2.0, 16.0)
        v = vertical(horde, [(0, 3.0, ["WHEN THE HORDE", "ARRIVES..."]), (3.0, 9.0, ["...AND YOUR BUILD", "IS MAXED OUT"]),
                             (9.0, 14.0, ["COMBO x50+", "EAT EVERYTHING"])])
        v += end_card((1080, 1920), 2.5, "keyart_1080x1920.png")
        h1, sr = audio("horde", 2.0, 16.0)
        write(v, [fade(h1, sr), silence(2.5)], os.path.join(OUT, "short_horde_1080x1920.mp4"))

    # ------------------------------------------ Play Store promo (16:9, ~30s)
    if "promo" in only:
        parts, auds = [], []

        def add(clip, t0, t1, caps):
            fr = seg(clip, t0, t1)
            parts.extend(landscape(fr, caps))
            a, s = audio(clip, t0, t1)
            auds.append(fade(a, s, 0.05, 0.15))

        add("titan", 2.4, 7.4, [(0, 5, ["GET SWALLOWED BY A TITAN", "AND FIGHT FROM THE INSIDE"])])
        evo = frames_for("dourado", 640, 360, 3, FPS, hold=1.0)
        parts.extend(f.convert("RGB") for f in evo)
        auds.append(silence(len(evo) / FPS))
        add("horde", 9.0, 14.0, [(0, 5, ["BUILD YOUR RUN", "WEAPONS, SYNERGIES, FUSIONS"])])
        add("lev", 15.5, 20.0, [(0, 4.5, ["33 ANIMALS", "EACH MOVES ITS OWN WAY"])])
        add("kraken", 14.5, 18.5, [(0, 4, ["COLOSSAL BOSSES", "KRAKEN, LEVIATHAN, MEGALODON"])])
        parts.extend(end_card((1920, 1080), 3.0, "keyart_1920x1080.png", "PLAY FREE ON GOOGLE PLAY"))
        auds.append(silence(3.0))
        write(parts, auds, os.path.join(OUT, "promo_googleplay_1920x1080.mp4"))
    print("ok")
