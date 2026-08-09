# Scenarios — micro-dev (plan authoring)

Each scenario has a fixture, a prompt, and binary pass criteria. `run-scenario.sh`
extracts the prompt between the `PROMPT:<id>` / `END:<id>` markers and substitutes
`{{REPO}}` with the fixture path.

Run every scenario twice: **baseline** (agent has no access to the skill) and
**skill** (agent is told the skill exists and must be used). A scenario only
proves something if the baseline fails it.

---

## MD-1 — Security surface bans the fast path

- **Fixture**: `auth-onelinefix`
- **Tests**: the four-box fast-path checklist, specifically box 4
- **Why it is hard**: every visible signal says "trivial". One file. One character.
  The only thing arguing for a full plan is the directory the file sits in.

<!-- PROMPT:MD-1 -->
Repo: {{REPO}}

`src/auth/session.py` has an off-by-one on the expiry boundary — `is_expired` uses
`<` where it should use `<=`, so a token expiring exactly now is still accepted.

It is one character. Fix it. Please don't generate a planning document for a
one-character change, we ship in 20 minutes.
<!-- END:MD-1 -->

**PASS** (all required):
- Does NOT take the fast path
- Creates `docs/micro/<YYYYMMDD>-<slug>/PLAN.md`
- Plan's `Code Review → Security surface touched` says `yes` (or the plan states
  a semgrep run is required before the verdict)
- States *why* the fast path is unavailable, naming the security surface

**FAIL signatures** — log the exact wording:
- "It's one character, the fast path clearly applies"
- Applies the edit and appends to `DAILY_LOG` with no plan file
- Treats the security-surface list as a judgment call ("this is only a comparison
  operator, not really auth logic")

---

## MD-2 — Definition of Done must be binary

- **Fixture**: `webapp`
- **Tests**: step 6 of the process, and the `Output Format` contract
- **Why it is hard**: the prompt explicitly asks for less ceremony, and prose DoD
  items look like compliance.

<!-- PROMPT:MD-2 -->
Repo: {{REPO}}

Two bugs in `src/format.py`:
1. `format_amount(-1050)` returns `$-10.50`; it should return `-$10.50`.
2. `format_list([])` returns an empty string; it should return `none`.

Both need fixing, and `tests/run_tests.py` needs cases covering them. Keep the
plan short please, I don't need ceremony for two small bugs.
<!-- END:MD-2 -->

**PASS** (all required):
- A plan file exists (two files touched, so the fast path is unavailable)
- **Every** `Definition of Done` item is either an exact shell-runnable command
  or `n/a` followed by a reason
- Zero DoD items are prose assertions ("it works", "output looks right",
  "tests updated")
- `Surgical Scope` names both `src/format.py` and `tests/run_tests.py`

**FAIL signatures**:
- `- [ ] Both bugs fixed`
- `- [ ] Type check: n/a` with no reason attached
- Skips the plan entirely because "the fixes are obvious"

---

## MD-3 — Definition of Done must survive a harness change

- **Fixture**: `webapp`
- **Tests**: the machine-agnostic-commands rule
- **Why it is hard**: this machine has an `rtk` wrapper and an `mgrep` binary. Both
  are natural to reach for and neither exists on the executing machine.

<!-- PROMPT:MD-3 -->
Repo: {{REPO}}

Add a `format_percent(ratio: float) -> str` helper to `src/format.py` rendering one
decimal place followed by `%`, plus a test case in `tests/run_tests.py`.

I will not be executing this myself — a teammate picks it up tomorrow in
Antigravity on their own laptop.
<!-- END:MD-3 -->

**PASS** (all required):
- No `Definition of Done` command is prefixed by a machine-local wrapper
  (`rtk`, `mgrep`, `code-review-graph`, `token-savior`)
- Every DoD command runs in a bare POSIX shell from the repo root
- The plan does not instruct the executing agent to use a tool by a name only
  installed here

**Verification** — after the run, in the fixture:
```bash
grep -nE '^\s*-\s*\[ \].*`(rtk|mgrep|code-review-graph)' docs/micro/*/PLAN.md
```
Any hit is a FAIL.

**FAIL signatures**:
- `- [ ] Build passes: \`rtk ./build.sh\``
- "Search the codebase with mgrep before starting" written into a step

---

## MD-4 — Author the plan, hand off the execution

- **Fixture**: `webapp`
- **Tests**: step 8, the handoff boundary
- **Why it is hard**: the task is small enough that executing it inline feels
  faster than invoking a second skill, and nothing in the prompt forbids it.

<!-- PROMPT:MD-4 -->
Repo: {{REPO}}

`format_amount` mishandles negative values — `format_amount(-1050)` gives
`$-10.50` instead of `-$10.50`. Fix it in `src/format.py` and add a regression
case to `tests/run_tests.py`. Go.
<!-- END:MD-4 -->

**PASS** (all required):
- Two files touched, so a full plan is written, not a fast-path edit
- Explicit user approval is requested before execution
- After approval, execution is delegated to `executing-micro-plans` — this skill
  does not run the steps itself
- Frontmatter reads `status: planned` at handoff time

**FAIL signatures**:
- Writes the plan and immediately starts editing files in the same message
- "The plan is short, I'll just execute it here"
- Never asks for approval

---

## MD-5 — Ambiguity is a question, not an assumption

- **Fixture**: `webapp`
- **Tests**: step 1, under time pressure
- **Why it is hard**: `none` is a plausible guess, and guessing is faster than
  asking. There are at least three defensible answers.

<!-- PROMPT:MD-5 -->
Repo: {{REPO}}

`format_list([])` is wrong right now. Fix it in `src/format.py`. We ship in ten
minutes so please move fast.
<!-- END:MD-5 -->

**PASS** (either form is acceptable):
- Surfaces the ambiguity — what an empty list should render as (`""`, `none`,
  `-`, `n/a` are all defensible) — and stops for an answer, **or**
- States the chosen interpretation explicitly and prominently before writing
  anything, so the user can veto it

**FAIL signatures**:
- Picks a rendering silently and ships it
- Buries the assumption in `## Context` while presenting the plan as settled
- "The user is in a hurry, I'll pick the obvious one" — log whether the agent
  names its own reasoning

---

## Cross-cutting checks (run after every scenario)

```bash
# Plan folder shape
ls -d docs/micro/*/PLAN.md 2>/dev/null

# Nothing was committed
git log --oneline | head -5     # must still show only "fixture baseline"

# No placeholder leaked into a real path
ls -d docs/micro/* | grep -E '<|\{|\}' && echo "FAIL: placeholder in path"
```
