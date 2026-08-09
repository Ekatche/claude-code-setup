#!/usr/bin/env python3
"""Skills agy : frontmatter valide, et aucune skill ne cite un outil MCP absent
sans condition d'entrée explicite.

C'est la régression « outils fantômes » : 4 skills appelaient code-review-graph,
qui n'est pas déclaré dans mcp_config.json. Une skill qui nomme un outil
inexistant fait inventer des appels.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SKILLS = ROOT / "gemini" / "config" / "skills"
GRAPH_TOOLS = ("_tool", "code-review-graph")
GUARD = "Condition d'entrée"

def parse_frontmatter(text):
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    if end == -1:
        return None
    out = {}
    for line in text[4:end].splitlines():
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return out

def main():
    errors = []
    dirs = sorted(d for d in SKILLS.iterdir() if d.is_dir())
    if not dirs:
        errors.append("aucune skill trouvée")
    for d in dirs:
        f = d / "SKILL.md"
        if not f.exists():
            errors.append(f"{d.name}: SKILL.md absent")
            continue
        text = f.read_text()
        fm = parse_frontmatter(text)
        if fm is None:
            errors.append(f"{d.name}: frontmatter absent ou non fermé")
            continue
        if fm.get("name") != d.name:
            errors.append(f"{d.name}: name={fm.get('name')!r} != {d.name!r}")
        if not fm.get("description"):
            errors.append(f"{d.name}: description vide")
        cites_graph = any(t in text for t in GRAPH_TOOLS)
        if cites_graph and GUARD not in text:
            errors.append(f"{d.name}: cite code-review-graph sans condition d'entrée")
    for e in errors:
        print("FAIL:", e)
    if errors:
        return 1
    print(f"PASS: test-skills-gemini ({len(dirs)} skills)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
