import json
import math
import re
import textwrap
import urllib.request
from collections import defaultdict
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    Image,
    KeepTogether,
    NextPageTemplate,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "saipos-menu.json"
OUT = ROOT / "cardapio-makau-poke.pdf"
LOGO = ROOT / "makau-poke-logo.png"
CUSTOM_LOGO = ROOT / "makau-poke-logo-source.png"
REDRAWN_LOGO = ROOT / "makau-poke-logo-redrawn.png"
FINAL_LOGO = ROOT / "makau-poke-logo-final.png"


def clean(text):
    if not text:
        return ""
    text = re.sub(r"\s+", " ", str(text)).strip()
    return text


def money(value):
    return f"R$ {value:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def item_price(item):
    variations = [v for v in item.get("variations", []) if v.get("enabled") == "Y"]
    if not variations:
        return ""
    if len(variations) == 1:
        return money(float(variations[0]["price"]))
    parts = []
    for var in sorted(variations, key=lambda v: v.get("order", 0)):
        name = clean(var.get("variation", {}).get("desc_store_variation"))
        parts.append(f"{name}: {money(float(var['price']))}")
    return " | ".join(parts)


def get_choice_map(data):
    return {choice["id_store_choice"]: choice for choice in data.get("choices", [])}


def choice_item_label(option):
    label = clean(option.get("desc_store_choice_item_deli") or option.get("desc_store_choice_item"))
    additions = [
        float(var.get("aditional_price", 0))
        for var in option.get("variations", [])
        if var.get("aditional_price")
    ]
    if not additions and "tropical" in label.lower():
        additions = [3.0]
    if additions:
        label = f"{label} (+{money(max(additions))})"
    return label


def choice_summary(item, choices_by_id):
    lines = []
    for link in sorted(item.get("choices", []), key=lambda c: c.get("order", 0)):
        choice = choices_by_id.get(link.get("id_store_choice"))
        if not choice:
            continue
        title = clean(choice.get("desc_store_choice_delivery") or choice.get("desc_store_choice"))
        options = [
            choice_item_label(opt)
            for opt in sorted(choice.get("choice_items", []), key=lambda o: o.get("order", 0))
            if opt.get("enabled") == "Y"
        ]
        options = [o for o in options if o]
        if not options:
            continue
        separator = " " if title.endswith(".") else ": "
        lines.append(f"<b>{title}</b>{separator}{', '.join(options)}")
    return lines


def download_logo(data):
    stores = data.get("stores") or []
    logo_path = None
    if stores:
        logo_path = stores[0].get("photo_site_logo")
    if not logo_path:
        return None
    try:
        urllib.request.urlretrieve(f"https://static.saipos.com/{logo_path}", LOGO)
        return LOGO
    except Exception:
        return None


class MenuDoc(BaseDocTemplate):
    def __init__(self, filename):
        super().__init__(
            filename,
            pagesize=A4,
            leftMargin=13 * mm,
            rightMargin=13 * mm,
            topMargin=14 * mm,
            bottomMargin=13 * mm,
        )
        width = self.width
        gutter = 7 * mm
        col_w = (width - gutter) / 2
        frames = [
            Frame(self.leftMargin, self.bottomMargin, col_w, self.height, id="left"),
            Frame(self.leftMargin + col_w + gutter, self.bottomMargin, col_w, self.height, id="right"),
        ]
        self.addPageTemplates([PageTemplate(id="columns", frames=frames)])


def page_footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#5f6f64"))
    canvas.drawCentredString(A4[0] / 2, 7 * mm, f"Makau Poke - cardapio fisico | pagina {doc.page}")
    canvas.restoreState()


def make_styles():
    sample = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "title",
            parent=sample["Title"],
            fontName="Helvetica-Bold",
            fontSize=29,
            leading=32,
            textColor=colors.HexColor("#111111"),
            alignment=TA_CENTER,
            spaceAfter=6,
        ),
        "subtitle": ParagraphStyle(
            "subtitle",
            parent=sample["BodyText"],
            fontName="Helvetica",
            fontSize=10.5,
            leading=14,
            textColor=colors.HexColor("#4d5b50"),
            alignment=TA_CENTER,
            spaceAfter=16,
        ),
        "category": ParagraphStyle(
            "category",
            parent=sample["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=14,
            leading=16,
            textColor=colors.white,
            backColor=colors.HexColor("#f47b20"),
            borderPadding=(4, 6, 4),
            spaceBefore=9,
            spaceAfter=6,
        ),
        "item": ParagraphStyle(
            "item",
            parent=sample["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=9.4,
            leading=11.2,
            textColor=colors.HexColor("#111111"),
        ),
        "desc": ParagraphStyle(
            "desc",
            parent=sample["BodyText"],
            fontName="Helvetica",
            fontSize=7.8,
            leading=9.5,
            textColor=colors.HexColor("#505a52"),
        ),
        "price": ParagraphStyle(
            "price",
            parent=sample["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=9.3,
            leading=11,
            textColor=colors.HexColor("#0f6b3f"),
            alignment=TA_RIGHT,
        ),
        "small": ParagraphStyle(
            "small",
            parent=sample["BodyText"],
            fontName="Helvetica",
            fontSize=7.2,
            leading=8.8,
            textColor=colors.HexColor("#4e594f"),
        ),
        "note": ParagraphStyle(
            "note",
            parent=sample["BodyText"],
            fontName="Helvetica",
            fontSize=8,
            leading=10,
            textColor=colors.HexColor("#3f473f"),
            alignment=TA_CENTER,
        ),
    }


def build_menu():
    data = json.loads(SOURCE.read_text(encoding="utf-8-sig"))
    styles = make_styles()
    choices_by_id = get_choice_map(data)
    logo = download_logo(data)

    grouped = defaultdict(list)
    category_order = {}
    for item in data.get("items", []):
        if item.get("enabled", "Y") != "Y":
            continue
        category = item.get("category_item") or {}
        if category.get("enabled", "Y") != "Y":
            continue
        cat_name = clean(category.get("desc_store_category_item") or "Outros")
        grouped[cat_name].append(item)
        category_order[cat_name] = category.get("order", 999)

    story = []
    logo_path = FINAL_LOGO if FINAL_LOGO.exists() else REDRAWN_LOGO if REDRAWN_LOGO.exists() else CUSTOM_LOGO
    if logo_path.exists():
        img = Image(str(logo_path), width=54 * mm, height=32 * mm)
        img.hAlign = "CENTER"
        story.append(img)
        story.append(Spacer(1, 2 * mm))
    else:
        story.append(Paragraph("Makau Poke - Cardapio", styles["title"]))
        story.append(Paragraph("Hawaiian Sushi Food", styles["subtitle"]))

    for cat_name in sorted(grouped, key=lambda c: (category_order[c], c)):
        items = sorted(grouped[cat_name], key=lambda it: (it.get("order", 0), it.get("desc_store_item", "")))
        story.append(Paragraph(cat_name, styles["category"]))
        for item in items:
            name = clean(item.get("desc_store_item_delivery") or item.get("desc_store_item"))
            detail = clean(item.get("detail"))
            price = item_price(item)
            item_lines = [[Paragraph(name, styles["item"]), Paragraph(price, styles["price"])]]
            table = Table(item_lines, colWidths=[68 * mm, 19 * mm], hAlign="LEFT")
            table.setStyle(
                TableStyle(
                    [
                        ("VALIGN", (0, 0), (-1, -1), "TOP"),
                        ("LEFTPADDING", (0, 0), (-1, -1), 0),
                        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
                        ("TOPPADDING", (0, 0), (-1, -1), 0),
                        ("BOTTOMPADDING", (0, 0), (-1, -1), 1.5),
                    ]
                )
            )
            block = [table]
            if detail:
                block.append(Paragraph(detail, styles["desc"]))
            if cat_name in {"POKE (MONTE O SEU)", "POKES PRONTOS"}:
                for line in choice_summary(item, choices_by_id):
                    block.append(Paragraph(line, styles["small"]))
            block.append(Spacer(1, 3.8 * mm))
            story.append(KeepTogether(block))

    doc = MenuDoc(str(OUT))
    for template in doc.pageTemplates:
        template.onPage = page_footer
    doc.build(story)


if __name__ == "__main__":
    build_menu()
    print(OUT)
