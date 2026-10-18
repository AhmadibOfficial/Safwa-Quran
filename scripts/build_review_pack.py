#!/usr/bin/env python3
"""Prepare a private offline source-review dossier. NEVER activates Quran assets."""
import argparse
import csv
from difflib import SequenceMatcher
from html import escape
import json
from pathlib import Path
import unicodedata

from compare_uthmani_editions import (
    audit, parse_primary, parse_secondary, git_sha, IntegrityError
)

ROOT = Path(__file__).resolve().parents[1]
SOURCE_A = ROOT / "sources/review_only/tanzil_uthmani_1.1_verbatim.txt"
SOURCE_B = ROOT / "sources/review_only/secondary_tanzil_uthmani_verbatim.txt"
CATALOG = ROOT / "assets/data/chapters.tsv"
COPYRIGHT_MARKER = "# PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK"


def codepoints(text):
    """Return every codepoint without rewriting or normalizing sacred text."""
    return [
        {"codepoint": f"U+{ord(char):04X}",
         "character": char,
         "name": unicodedata.name(char, "UNASSIGNED")}
        for char in text
    ]


def edit_operations(before, after):
    operations = []
    for tag, i, j, k, n in SequenceMatcher(
        a=before, b=after, autojunk=False
    ).get_opcodes():
        if tag == "equal":
            continue
        operations.append({
            "kind": tag,
            "source": codepoints(before[i:j]),
            "comparison": codepoints(after[k:n]),
        })
    return operations


def make_rows(primary, secondary, refs):
    results = []
    for reference in refs:
        chapter, ayah = (int(part) for part in reference.split(":"))
        key = (chapter, ayah)
        first, second = primary[key], secondary[key]
        if first == second or first.replace("\u0640", "") == second.replace("\u0640", ""):
            raise IntegrityError("Review queue contains an already-explained pair " + reference)
        results.append({
            "reference": reference,
            "primary": first,
            "secondary": second,
            "unicode_operations": edit_operations(first, second),
        })
    return results


def build_html(rows, evidence, copyright_block):
    # No JavaScript, remote fonts, tracking or external content requests.
    body = []
    for row in rows:
        ops = json.dumps(row["unicode_operations"], ensure_ascii=False, indent=2)
        body.append(
            f'<article class="verse"><h2>{escape(row["reference"])}</h2>'
            '<div class="columns">'
            f'<section><h3>Primary pinned Tanzil copy</h3><p lang="ar" dir="rtl">{escape(row["primary"])}</p></section>'
            f'<section><h3>Secondary preserved copy</h3><p lang="ar" dir="rtl">{escape(row["secondary"])}</p></section>'
            '</div><details><summary>Exact Unicode edit operations (diagnostic only)</summary>'
            f'<pre>{escape(ops)}</pre></details></article>'
        )
    return """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline';">
<title>Safwa Quran — unapproved source comparison</title>
<style>
:root{color-scheme:light;font-family:system-ui,sans-serif;color:#1d2943;background:#faf9f5}
body{max-width:1100px;margin:auto;padding:clamp(12px,3vw,40px)}
h1,h2{color:#15294c}.notice{border-inline-start:5px solid #a7864b;padding:16px;background:white}
.verse{border:1px solid #dce0e5;border-radius:12px;padding:18px;margin:18px 0;background:white}
.columns{display:grid;grid-template-columns:1fr 1fr;gap:18px}
section{min-width:0}section h3{font-size:0.85rem}
[lang="ar"]{font-family:"Noto Naskh Arabic","Amiri",serif;font-size:1.7rem;line-height:2.3;overflow-wrap:anywhere}
pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:0.8rem}
small{color:#5b6370}@media(max-width:650px){.columns{grid-template-columns:1fr}}
</style></head><body><main>
<h1>Safwa Quran — private source review</h1>
<p class="notice"><strong>NOT VERIFIED OR APPROVED.</strong> This is a comparison-only research
document, not a Quran reader or authoritative Mushaf. Do not edit these source strings,
publish this document as devotional content, or use it to issue religious approval.</p>
<p>Six thousand two hundred thirty-six verse references checked. """+str(evidence["remaining_count"])+""" strings remain different after diagnostic comparison-only tatweel handling.
Two independent qualified reviews and official-source confirmation are still pending.</p>
<p><small>Source integrity is recorded in manifest.json. Individual codepoints may represent
valid orthographic conventions; automated differences do not imply errors.</small></p>
"""+"\n".join(body)+"""
<h2>Unmodified Tanzil copyright and terms</h2><pre>"""+escape(copyright_block)+"""</pre>
<p>Source and updates: <a href="https://tanzil.net/">Tanzil Project</a>
(cannot load in offline mode).</p></main></body></html>
"""


def build(out_dir, source_a=SOURCE_A, source_b=SOURCE_B, catalog=CATALOG):
    if out_dir.resolve() in (ROOT.resolve(), source_a.parent.resolve()):
        raise IntegrityError("Output cannot overwrite source directories")
    summary = audit(source_a, source_b, catalog)
    raw = source_a.read_bytes().decode("utf-8-sig")
    if COPYRIGHT_MARKER not in raw:
        raise IntegrityError("Source license notice missing")
    notice = raw[raw.index(COPYRIGHT_MARKER):]
    first = parse_primary(source_a.read_bytes())
    second = parse_secondary(source_b.read_bytes(), list(first))
    refs = summary["remaining_references"]
    rows = make_rows(first, second, refs)
    if len(rows) != summary["remaining_count"]:
        raise IntegrityError("Unexpected Quran review queue size")
    out_dir.mkdir(parents=True, exist_ok=True)
    with (out_dir / "unresolved_verses.csv").open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=["reference", "primary", "secondary", "unicode_operations"])
        writer.writeheader()
        for row in rows:
            writer.writerow({
                "reference": row["reference"],
                "primary": row["primary"],
                "secondary": row["secondary"],
                "unicode_operations": json.dumps(row["unicode_operations"], ensure_ascii=False),
            })
    (out_dir / "index.html").write_text(build_html(rows, summary, notice), encoding="utf-8")
    manifest = {
        "review_status": "UNAPPROVED",
        "release_allowed": False,
        "reviewers": [],
        "primary_git_sha1": git_sha(source_a.read_bytes()),
        "secondary_git_sha1": git_sha(source_b.read_bytes()),
        "official_tanzil_download_verified": False,
        "unresolved_count": len(rows),
        "reference_list": refs,
        "caution": "This review pack is not evidence of theological or scholarly approval.",
    }
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return manifest


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--out", type=Path, default=ROOT / ".staging/review-pack")
    args = p.parse_args()
    try:
        manifest = build(args.out)
    except (ValueError, OSError, UnicodeError, KeyError, TypeError) as ex:
        p.exit(1, "ERROR: " + str(ex) + "\n")
    print("Private Quran-review package built:", args.out)
    print("Unresolved references:", manifest["unresolved_count"])
    print("Approval: PENDING; public release: BLOCKED")


if __name__ == "__main__":
    main()
