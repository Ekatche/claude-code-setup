# PLAN.md Template — micro-dev

Copy the block below to `docs/micro/<YYYYMMDD>-<slug>/PLAN.md`.

Section headings are a contract: `executing-micro-plans` reads them by name, possibly on a different harness. Do not rename, reorder, merge, or drop any of them. Sections that do not apply get an explicit `n/a` with a reason, never a blank.

---

```markdown
---
task: <one-line description of what this task achieves>
status: planned
created: <YYYY-MM-DD>
---

# <Task Title>

## Context
- Existing code checked: <what was found — files, functions, imports scanned>
- Fresh info looked up: <library/API/CLI documentation consulted, or "n/a">
- Git status checked: clean / <uncommitted state found and how it was handled>

## Simpler Alternative Considered
<the simpler approach, if one exists, or "none — request is already the minimal change">

## Surgical Scope
- **Files touched**:
  - `path/to/file_a.py`
  - `path/to/file_b.ts`
- **Files NOT touched**: all others
- **Symbols replaced** (→ must delete before done):
  - `old_function_name` in `path/to/file_a.py`
- **Symbols extended** (→ keep, add or modify only):
  - `existing_class` in `path/to/file_b.ts`

## Definition of Done
- [ ] Build passes: `cd backend && uv run python -c "import app"`
- [ ] Tests pass: `cd backend && uv run pytest tests/test_file_a.py -q`
- [ ] No dead code: `old_function_name` confirmed removed (0 callers)
- [ ] Type check: `cd backend && uv run mypy path/to/file_a.py`
- [ ] Manual check: `POST /api/endpoint` returns 200 with the new field

## Steps
- [ ] Step 1: <concrete, atomic action — one file, one concern>
- [ ] Step 2: <concrete, atomic action>
- [ ] Step 3 (teardown): Delete all dead code created by this plan (`old_function_name`). Run an orphan scan bounded to that symbol. Confirm 0 orphans.

## Code Review
- Dead code removed: yes / no (list remaining if no)
- Build status: pass / fail (fix applied: <describe>)
- Type errors: none / fixed (<describe>)
- Unintended side effects: none / (<describe>)
- Security surface touched: no / yes (semgrep run: pass/fail)
- Verdict: ✅ DONE / ⚠️ BLOCKED (<reason>)

## Execution Log
(append-only, filled by executing-micro-plans: `<UTC timestamp> | <harness> | step N | <state> | <evidence>`)

## Notes
(deviations from plan, errors hit during execution, corrections applied)
```

---

## Writing the Definition of Done

Every item is one of two things: an **exact command a shell can run**, or `n/a` followed by the reason.

| Bad | Why | Good |
|---|---|---|
| `- [ ] It works` | Not binary, nothing to run | `- [ ] Build passes: \`pnpm build\`` |
| `- [ ] Tests pass` | Which tests? | `- [ ] Tests pass: \`pnpm test src/auth\`` |
| `- [ ] Type check: n/a` | No reason given | `- [ ] Type check: n/a — plain JS, no type system` |
| `- [ ] Build passes: \`rtk pnpm build\`` | Machine-local wrapper | `- [ ] Build passes: \`pnpm build\`` |

The last row is the one that breaks cross-harness execution: a plan whose commands only run on one machine cannot be picked up anywhere else.

## Pre-execution checklist

- [ ] `Surgical Scope` lists real file paths, not placeholders
- [ ] Every `Definition of Done` item is an exact runnable command or an `n/a` with a reason
- [ ] No `Definition of Done` command depends on a machine-local wrapper
- [ ] `Symbols replaced` lists every symbol that must be deleted before done
- [ ] `Simpler Alternative Considered` is filled — a real option or "none"
- [ ] The last step is the teardown step, and it names the symbols to scan
- [ ] `## Execution Log` and `## Notes` sections exist, even if empty
- [ ] No touched file is on the security surface, or the plan accounts for it (see SKILL.md § Security Notes)
- [ ] The user approved this plan
