#!/usr/bin/env python3
"""Frontmatter des agents : YAML parsable, name == nom de fichier, model non vide.

Pas de PyYAML : la CI ne doit dépendre que de la stdlib. Le frontmatter des
agents est plat (clé: valeur), un parseur minimal suffit et ne peut pas
diverger d'une version de lib à l'autre.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
AGENTS = ROOT / "claude" / "agents"
EXPECTED = 17

def parse_frontmatter(text):
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    if end == -1:
        return None
    out = {}
    for line in text[4:end].splitlines():
        if not line.strip() or line.startswith("#") or line.startswith(" "):
            continue
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        out[k.strip()] = v.strip()
    return out

def main():
    files = sorted(AGENTS.glob("*.md"))
    errors = []
    if len(files) != EXPECTED:
        errors.append(f"{len(files)} agents, {EXPECTED} attendus")
    for f in files:
        fm = parse_frontmatter(f.read_text())
        if fm is None:
            errors.append(f"{f.name}: frontmatter absent ou non fermé")
            continue
        if fm.get("name") != f.stem:
            errors.append(f"{f.name}: name={fm.get('name')!r} != {f.stem!r}")
        if not fm.get("model"):
            errors.append(f"{f.name}: model vide ou absent")
        if not fm.get("description"):
            errors.append(f"{f.name}: description vide ou absente")
    for e in errors:
        print("FAIL:", e)
    if errors:
        return 1
    print(f"PASS: test-agents ({len(files)} agents)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
