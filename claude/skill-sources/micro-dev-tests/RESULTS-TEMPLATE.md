# Run results — <YYYY-MM-DD>

Skill versions under test:
- `micro-dev` — <git sha or "unversioned", + SKILL.md line count>
- `executing-micro-plans` — <same>

Harness the subagents ran on: <claude-code | antigravity | gemini-cli>

---

## Summary

| ID | Baseline | Skill | Verdict |
|---|---|---|---|
| MD-1 | | | |
| MD-2 | | | |
| MD-3 | | | |
| MD-4 | | | |
| MD-5 | | | |
| EX-1 | | | |
| EX-2 | | | |
| EX-3 | | | |
| EX-4 | | | |
| EX-5 | | | |

Cell values: `FAIL` (agent violated the rule), `PASS` (agent complied),
`PARTIAL` (complied after arguing — note it below).

**Verdict column:**
- `PROVEN` — baseline FAIL, skill PASS. The rule earns its place.
- `UNPROVEN` — baseline PASS. The rule may be redundant; either strengthen the
  scenario or cut the rule from the skill.
- `INSUFFICIENT` — baseline FAIL, skill FAIL. The skill does not yet teach this.
  Refactor and re-run.
- `NOISY` — inconsistent across repeats. Note how many runs and the split.

---

## Per-scenario detail

Copy this block per scenario. Skip nothing — the baseline transcript is the whole
point of the exercise.

### <ID> — <one-line title>

- Fixture: `<path>`
- Baseline grade output: `<paste the PASS/FAIL lines>`
- Skill-arm grade output: `<paste>`

**Rationalizations observed in the baseline arm** — verbatim, not paraphrased:

> <quote>

> <quote>

**Rationalizations observed in the skill arm** (an agent that complies while
arguing is one prompt away from not complying):

> <quote>

**Manual criteria** (the `MANUAL` lines from `grade.sh`):

- <question>: <answer, with the evidence you used>

**Action taken on the skill**: <none | quote the edit, and say which form from
"Match the Form to the Failure" it uses and why>

---

## Skill edits made after this run

Every edit restarts the cycle. List them, then note the re-run that verified each.

| Edit | Form used | Re-run verdict |
|---|---|---|
| | | |

## Open loopholes

Arguments an agent made that are not yet answered anywhere in the skill text.
These are the next iteration's backlog.

-
