#!/usr/bin/env python3
"""Project docs/stories/*.examplemap into tests/acceptance/features/*.feature.

The .examplemap is the discovery source; the .feature is a regenerated projection
(docs/ai/doctrines/examplemap-doctrine.md). Each feature records the sha256 of the map it came
from so drift is detectable (docs/ai/20-review-and-delivery-policy.md, "GitOps projections").

Mapping: story -> Feature; rule -> comment block (plus a rule-id tag on its scenarios);
example -> Scenario; repeated given/when/then -> And. Examples with no steps are listed as
comments. Red cards (questions) have no Gherkin: the file states how many were left out.

Usage: python3 tools/sdlc/examplemap_to_feature.py [--check]
  --check  exit 1 if any feature is missing or stale (for CI).
"""
from __future__ import annotations

import hashlib
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import dsl  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC_DIR = os.path.join(ROOT, "docs", "stories")
OUT_DIR = os.path.join(ROOT, "tests", "acceptance", "features")
DELIVERY_TAGS = {"Walking skeleton": "WS-01", "MVP": "MVP-01"}
ORDER = {"given": 0, "when": 1, "then": 2}


def gherkin_tag(t: str) -> str:
    return "@" + "".join(ch if ch.isalnum() or ch in "-_." else "-" for ch in t)


def render(path: str) -> str:
    raw = open(path, "rb").read()
    digest = hashlib.sha256(raw).hexdigest()
    res = dsl.parse_examplemap(raw.decode("utf-8"), path)
    if res.errors:
        raise SystemExit(f"{path}: {res.errors}")
    m = res.model
    story = m["story"]
    rel = os.path.relpath(path, ROOT)
    n_questions = len(story["questions"]) if story else 0
    n_questions += sum(len(r["questions"]) for r in m["rules"])
    out = [
        f"# GENERATED from {rel} — do not edit; change the example map and regenerate.",
        f"# source-sha256: {digest}",
        f"# generator: tools/sdlc/examplemap_to_feature.py",
        f"# {n_questions} open question(s) on the map have no Gherkin and are NOT represented here.",
        "# Status: PROPOSED examples, not yet accepted by a Three Amigos session.",
    ]
    feature_tags = [gherkin_tag(t) for t in (story["tags"] if story else []) if t.upper().startswith("STORY-")]
    if feature_tags:
        out.append(" ".join(feature_tags))
    out.append(f"Feature: {story['title'] if story else m['title']}")
    if story:
        c = story["clauses"]
        out += [f"  As {c.get('as', '?')}", f"  I want {c.get('want', '?')}", f"  So that {c.get('so', '?')}"]
    for rule in m["rules"]:
        rid = next((t for t in rule["tags"] if t.upper().startswith("R-")), None)
        out.append("")
        out.append(f"  # Rule{' ' + rid if rid else ''}: {' '.join(rule['text'].split())}")
        if not rule["examples"]:
            out.append("  # (no examples — this rule contributes nothing executable)")
        for ex in rule["examples"]:
            if not ex["steps"]:
                out.append(f"  # Example named but not written out: {ex['title']}")
                continue
            tags = []
            if ex["release"]:
                tags.append("@" + DELIVERY_TAGS.get(ex["release"], ex["release"].replace(" ", "-")))
            if rid:
                tags.append(gherkin_tag(rid))
            tags += [gherkin_tag(t) for t in ex["tags"]]
            out.append("")
            out.append("  " + " ".join(tags))
            out.append(f"  Scenario: {ex['title']}")
            prev = None
            for kw, text in sorted(ex["steps"], key=lambda s: ORDER[s[0]]):
                word = "And" if kw == prev else kw.capitalize()
                out.append(f"    {word} {text}")
                prev = kw
    return "\n".join(out) + "\n"


def main() -> int:
    check = "--check" in sys.argv
    os.makedirs(OUT_DIR, exist_ok=True)
    stale = []
    for name in sorted(os.listdir(SRC_DIR)):
        if not name.endswith(".examplemap"):
            continue
        text = render(os.path.join(SRC_DIR, name))
        target = os.path.join(OUT_DIR, name.replace(".examplemap", ".feature"))
        current = open(target).read() if os.path.exists(target) else None
        if current != text:
            stale.append(os.path.relpath(target, ROOT))
            if not check:
                with open(target, "w") as fh:
                    fh.write(text)
    if check and stale:
        print("stale or missing features:", *stale, sep="\n  ")
        return 1
    print(("up to date" if check else "written") + f": {len(os.listdir(OUT_DIR))} feature file(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
