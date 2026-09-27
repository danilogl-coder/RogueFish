"""'Larva to Legend' animation: an animal swims through its five life
stages, each change marked by a flash and a pop, with the stage name.
Exports a looping GIF (social / Reddit) and MP4s (1:1 and 9:16)."""
import subprocess
import imageio_ffmpeg
from common import *

EN = json.load(open(os.path.join(ROOT, "assets", "i18n", "en.json")))
FF = imageio_ffmpeg.get_ffmpeg_exe()


def stage_names(species):
    txt = open(os.path.join(ROOT, "scripts", "data", "evolutions.gd")).read()
    import re
    block = re.search(r'"%s": \[(.*?)\]\],' % species, txt, re.S).group(1)
    return [EN.get(n, n) for n in re.findall(r'\["([^"]+)", "', block)]


def frames_for(species, w, h, k, fps, hold=1.3, title=True, bg_seed=3):
    base = ocean(w, h, bg_seed)
    seabed(base, h - 18, bg_seed)
    names = stage_names(species)
    sprites = [[trim(player_frame(species, s, f)) for f in range(6)] for s in range(5)]
    # integer zoom so the legendary form fills ~60% of the width
    widest = max(max(f.width for f in st) for st in sprites)
    z = max(1, int(w * 0.6 / widest))
    sprites = [[up(f, z) for f in st] for st in sprites]
    out = []
    n_hold = int(hold * fps)
    for s in range(5):
        for i in range(n_hold):
            im = base.copy()
            t = i / fps
            spr = sprites[s][int(t * 10) % 6]
            pop = 1.0
            if i < 4 and s > 0:
                pop = [1.35, 1.2, 1.1, 1.03][i]
            if pop != 1.0:
                spr = spr.resize((max(1, int(spr.width * pop)), max(1, int(spr.height * pop))), Image.NEAREST)
            bob = math.sin(t * 3.0) * 2
            paste(im, spr, w / 2, h * 0.52 + bob)
            if i < 5 and s > 0:
                # evolution flash: white burst + ring
                fl = Image.new("RGBA", (w, h), (255, 255, 255, [200, 140, 80, 40, 10][i]))
                im.alpha_composite(fl)
                d = ImageDraw.Draw(im)
                r = 20 + i * 14
                d.ellipse([w / 2 - r, h * 0.52 - r, w / 2 + r, h * 0.52 + r], outline=(120, 240, 255, 220), width=2)
            big = up(im, k)
            if title:
                text(big, "LARVA TO LEGEND", big.width / 2, int(big.height * 0.07), max(18, big.width // 24), outline=3)
            # stage label + progress pips
            label = names[s].upper()
            text(big, label, big.width / 2, int(big.height * 0.74), max(16, big.width // 30), col=CYAN, outline=3)
            d = ImageDraw.Draw(big)
            pw = big.width // 18
            x0 = big.width / 2 - (5 * pw + 4 * 8) / 2
            for j in range(5):
                col = GOLD if j <= s else (40, 70, 100)
                d.rectangle([x0 + j * (pw + 8), big.height * 0.8, x0 + j * (pw + 8) + pw, big.height * 0.8 + 8], fill=col)
            out.append(big.convert("RGB"))
    # hold the legend a bit longer
    out += out[-n_hold // 2:]
    return out


def save_gif(frames, path, fps):
    pal = [f.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
    pal[0].save(path, save_all=True, append_images=pal[1:], duration=int(1000 / fps), loop=0, optimize=True, disposal=1)


def save_mp4(frames, path, fps, audio=None, audio_start=0.0):
    w, h = frames[0].size
    cmd = [FF, "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{w}x{h}", "-r", str(fps), "-i", "-"]
    if audio:
        cmd += ["-ss", str(audio_start), "-i", audio, "-shortest", "-c:a", "aac", "-b:a", "160k"]
    cmd += ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "slow", "-movflags", "+faststart", path]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for f in frames:
        p.stdin.write(f.tobytes())
    p.stdin.close()
    p.wait()


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    music = os.path.join(ROOT, "assets", "audio", "music", "menu.ogg")
    for sp in ("dourado", "caranguejo", "agua_viva"):
        g = frames_for(sp, 240, 240, 2, 12)
        save_gif(g, os.path.join(OUT, f"gif_larva_to_legend_{sp}.gif"), 12)
    seq = []
    for sp in ("dourado", "caranguejo", "agua_viva"):
        seq += frames_for(sp, 270, 480, 4, 30, hold=1.1)
    save_mp4(seq, os.path.join(OUT, "short_larva_to_legend_1080x1920.mp4"), 30, music, 6.0)
    sq = []
    for sp in ("dourado", "caranguejo"):
        sq += frames_for(sp, 360, 360, 3, 30, hold=1.2)
    save_mp4(sq, os.path.join(OUT, "post_larva_to_legend_1080x1080.mp4"), 30, music, 6.0)
    print("ok")
