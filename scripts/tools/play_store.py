"""Google Play graphics: icon 512, feature banners (ru/en) 1024x500, 7 screenshots per language.

    python scripts/tools/play_store.py      (after: godot --path . --resolution 1920x1080 -- --autotest --shots-only --lang=ru|en --mood=day|night|sunset)
Output: renders/play/
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "renders", "play")
SHOTS = os.path.join(ROOT, "renders", "game")
os.makedirs(OUT, exist_ok=True)
FONT = os.path.join(ROOT, "assets", "fonts", "RussoOne-Regular.ttf")

PICK = ["day_01_title", "day_04_placement_done", "day_10_defense", "night_10_defense",
        "night_04_placement_done", "night_ability_radar", "sunset_04_placement_done"]


def icon():
    src = Image.open(os.path.join(ROOT, "concept", "scenes", "battle_day.png")).convert("RGB")
    src.crop((140, 300, 800, 960)).resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icon_512.png"))


def banner(lang):
    src = Image.open(os.path.join(ROOT, "concept", "scenes", "battle_day.png")).convert("RGB")
    w, h = src.size
    crop_h = int(w * 500 / 1024)
    top = (h - crop_h) // 2
    img = src.crop((0, top, w, top + crop_h)).resize((1024, 500), Image.LANCZOS)
    shade = Image.new("L", (1024, 500), 0)
    d = ImageDraw.Draw(shade)
    for y in range(500):
        d.line([(0, y), (1024, y)], fill=int(150 * max(0, 1 - y / 260)))
    img = Image.composite(Image.new("RGB", img.size, (2, 10, 20)), img, shade)
    title = "МОРСКОЙ БОЙ" if lang == "ru" else "SEA BATTLE"
    sub = "Флот против флота • 3D • онлайн" if lang == "ru" else "Fleet vs fleet • 3D • online"
    d = ImageDraw.Draw(img)
    f1 = ImageFont.truetype(FONT, 96)
    f2 = ImageFont.truetype(FONT, 34)
    for text, font, y, col in [(title, f1, 40, (255, 158, 51)), (sub, f2, 150, (90, 240, 255))]:
        tw = d.textlength(text, font=font)
        x = (1024 - tw) / 2
        d.text((x, y), text, font=font, fill=col, stroke_width=8 if font is f1 else 4, stroke_fill=(6, 14, 26))
    img.save(os.path.join(OUT, "feature_%s.png" % lang))


def screenshots(lang):
    for i, name in enumerate(PICK, 1):
        p = os.path.join(SHOTS, "%s%s.png" % (lang, name))
        if not os.path.exists(p):
            print("missing", p)
            continue
        Image.open(p).convert("RGB").save(os.path.join(OUT, "%s_%d.png" % (lang, i)))


if __name__ == "__main__":
    icon()
    for lang in ("ru", "en"):
        banner(lang)
        screenshots(lang)
    print(sorted(os.listdir(OUT)))
