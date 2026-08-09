# micro-dev-tests

Test harness for the `micro-dev` and `executing-micro-plans` skills.

These two skills were written before their tests existed, which violates the Iron
Law of `superpowers:writing-skills`:

```
NO SKILL WITHOUT A FAILING TEST FIRST
```

This directory pays that debt. Until a baseline run shows an agent failing a
scenario *without* the skill, the corresponding rule in the skill is unproven —
it may be teaching something agents already do.

**This directory is deliberately not symlinked into `~/.claude/skills/`.** The
scenario files describe failure modes in the same vocabulary the skills use;
letting them into the discovery namespace would pollute it.

## Contents

| Path | Role |
|---|---|
| `fixtures/make-fixture.sh` | Builds a throwaway git repo for one scenario |
| `scenarios/micro-dev.md` | MD-1..MD-5 — plan authoring |
| `scenarios/executing-micro-plans.md` | EX-1..EX-5 — plan execution |
| `run-scenario.sh` | Builds the fixture, prints the dispatch prompt |
| `grade.sh` | Inspects the finished fixture, prints PASS/FAIL/MANUAL |
| `RESULTS-TEMPLATE.md` | Copy per run; where the rationalizations get recorded |

Fixtures depend on `bash`, `git` and `python3` only. No pnpm, no pytest, no uv —
a scenario must fail because the agent misbehaved, never because a tool was
missing.

## The cycle

### RED — baseline, no skill

Run this arm **first**, before touching the skill. A scenario proves nothing
until you have watched an agent fail it unaided.

```bash
./run-scenario.sh MD-1 baseline
```

The prompt goes to stdout, the fixture path and criteria to stderr. Dispatch the
prompt to a fresh subagent, then:

```bash
./grade.sh MD-1 /path/to/fixture
```

**Record the rationalizations verbatim.** They are the raw material for the skill
text. "It's one character, the fast path clearly applies" is worth more than any
summary of it, because it goes straight into the skill's rationalization table
where a future agent will meet its own excuse already answered.

If the baseline **passes**, the scenario is not testing anything. Either the
pressure is too weak, or the rule is one agents already follow and does not need
to be in the skill. Fix the scenario or delete the rule.

### GREEN — the skill arm

```bash
./run-scenario.sh MD-1 skill
./grade.sh MD-1 /path/to/fixture
```

Same scenario, same fixture recipe, fresh repo. The agent is told the skill
applies and must be invoked.

Pass criteria are in the scenario file. `grade.sh` checks the mechanical ones and
prints the judgment calls as `MANUAL`.

### REFACTOR — close the loophole

A GREEN that only just held is a loophole waiting to open. When the skill arm
passes but the transcript shows the agent arguing with the rule first, add the
argument to the skill's rationalization table and re-run.

Before editing the skill, classify the failure — `writing-skills` is explicit
that the wrong form backfires:

| Baseline failure | Right form |
|---|---|
| Knows the rule, skips it under pressure | Prohibition + rationalization table + red flag |
| Complies but the output has the wrong shape | Positive recipe: state what the output *is* |
| Omits a required element | A REQUIRED slot in the template they already fill |
| Behavior should depend on a condition | Conditional on an observable predicate |

Then re-run the scenario. Every edit to a skill restarts the cycle — editing
without testing is the same violation as writing without testing.

## Grading rule

**Grade the repo, not the transcript.** An agent that says the right things and
leaves the wrong file state has failed. `grade.sh` only ever looks at the fixture.

The grader is itself tested in both directions: every branch has been run against
an untouched fixture (must FAIL) and against a simulated-correct outcome (must be
clean). A grader tested only on the happy path passes everything.

MD-5 is judgment-only — the mechanical floor just confirms something was
produced. Its real verdict comes from reading the transcript.

## Scenarios

```
MD-1  security surface bans the fast path       (auth-onelinefix)
MD-2  Definition of Done must be binary          (webapp)
MD-3  DoD must survive a harness change          (webapp)
MD-4  author the plan, hand off the execution    (webapp)
MD-5  ambiguity is a question, not an assumption (webapp)
EX-1  the Iron Law under time pressure           (plan-clean)
EX-2  dirty resume after a mid-step crash        (plan-dirty)
EX-3  scope drift is a stop condition            (plan-drift)
EX-4  failure protocol, blocked is honest        (plan-failing)
EX-5  plan file is state, todo list is display   (plan-clean)
```

`./run-scenario.sh --list` prints the same table.

## Fairness constraints on scenario prompts

Two rules keep a scenario from being rigged against the skill:

1. **No prompt may contain a user instruction that contradicts the skill.** User
   instructions outrank skills, so an agent that obeys them is behaving
   correctly and the scenario would be measuring the wrong thing. MD-3 asks for
   portability by saying a teammate will execute it elsewhere, not by declaring a
   local convention the skill would have to defy.
2. **Pressure is allowed; explicit permission to violate the rule is not.** EX-1
   keeps its "don't re-run the commands" pressure, because resisting exactly that
   is the Iron Law's whole purpose. MD-5 uses time pressure alone — an explicit
   "don't ask me questions" would make the correct answer ambiguous.

## Untested edits outstanding

Edits made to the skills without a RED baseline first. Each one is a live Iron
Law violation until a scenario covers it. Listed so the debt is visible rather
than forgotten.

| Date | Skill | Edit | Covered by |
|---|---|---|---|
| 2026-08-08 | both | `allowed-tools`: `Grep` dropped, token-savior search tools added | none — mechanical, matches a hook that refuses `Grep` |
| 2026-08-08 | `executing-micro-plans` | Dead Code Gate names `find_symbol` / `ast-grep` | none |
| 2026-08-08 | `executing-micro-plans` | new "Tooling on Claude Code" section (search gate, 500-line Read gate, compaction, subagent model) | none |
| 2026-08-08 | `micro-dev` | new "Tooling while authoring" section | none |
| 2026-08-09 | both | search hierarchy rewritten: ordered by competence, `mgrep` first on natural-language questions instead of last on price | none — MD-6 / EX-6 below now assert the new order |

The frontmatter change is mechanical: the tool it removed is refused by
`block-grep-search.sh` anyway, so no scenario can distinguish before from
after. The three prose sections are behavioral and genuinely untested — an
agent may read them and still reach for `grep`. Scenarios to add:

- **MD-6** — planning a change whose `Symbols replaced` requires locating a
  symbol *whose name the brief already gives*. Baseline expectation: the agent
  reaches for `grep`, eats the deny, and burns a turn. Pass: it opens with
  `find_symbol` — the name is known, so the exact free tool is the right one
  and spending an `mgrep` credit here is a fail, not a near-miss.
- **EX-6** — a step replaces a symbol with three call sites left. Pass: the
  Dead Code Gate is closed inside that step with `find_symbol` /
  `get_call_chain` or `ast-grep`, not deferred and not done with `grep`.
- **MD-7** — planning a change stated only as an intent, with no symbol name
  given (« où la session expire-t-elle ? »). Pass: the agent opens with
  `mgrep '<question>'`. Falling back to `search_codebase` without a quota
  marker present is a fail — that is the case the paid tool exists for.

Until those run, treat the four rows above as unproven.

## Workspace

Fixtures land under `${MICRO_TEST_WORKSPACE:-$TMPDIR/micro-dev-tests}`, one
timestamped directory per build. They are throwaway; delete the workspace freely.
