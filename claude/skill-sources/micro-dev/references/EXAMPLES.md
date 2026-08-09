# EXAMPLES.md — micro-dev

Three worked examples covering the common shapes. Match their form when writing a new plan.

Each example shows the finished artifact plus the reasoning that produced it.

---

## Example 1 — Bug fix (fast path)

> **Task**: `/api/documents` raises a `KeyError` when a document has no `metadata` field.

### Why the fast path applies

All four boxes check out:
- One file touched: `api/routes/document_router.py`
- One change: `.get("metadata", {})` instead of `["metadata"]`
- No interruption risk
- Not on the security surface (a read path, no auth, no validation, no injection)

### Execution

1. Locate the failing line with a semantic search on "metadata access in document router".
2. Apply the surgical fix.
3. Run the build command and read the exit code in the same message:
   `cd backend && uv run python -c "from api.routes import document_router"` → exit 0.
4. Confirm no dead code was created (no new function introduced, nothing replaced).
5. Append to `docs/micro/DAILY_LOG-2026-07-31.md`:

```markdown
- [x] 09:42 fix-metadata-keyerror — Fix KeyError on missing metadata field (`api/routes/document_router.py`)
```

### What would have forced a full plan

- The fix also needing a Pydantic schema update → two files.
- `metadata` turning out to be missing in three different routes → multiple steps.
- The same one-line fix inside `auth/session.py` → security surface, fast path banned regardless of size.

---

## Example 2 — Mini-feature (full plan, no dead code)

> **Task**: add a `page_count` field to the `GET /api/documents/{id}` response.

### Plan file

```markdown
---
task: Add page_count field to GET /api/documents/{id} response
status: planned
created: 2026-07-31
---

# Add page_count to document response

## Context
- Existing code checked: `DocumentResponse` in `models/document.py`, `get_document_by_id` in `services/document_service.py`, the `GET /{id}` route in `api/routes/document_router.py`
- Fresh info looked up: n/a — pure business logic, no external API
- Git status checked: clean

## Simpler Alternative Considered
none — the request is already the minimal change

## Surgical Scope
- **Files touched**:
  - `backend/models/document.py` (add field to the Pydantic model)
  - `backend/services/document_service.py` (populate the field from the DB)
- **Files NOT touched**: all others — the router is unchanged, the schema update propagates automatically
- **Symbols replaced** (→ must delete before done): none
- **Symbols extended** (→ keep):
  - `DocumentResponse` in `models/document.py`
  - `get_document_by_id` in `services/document_service.py`

## Definition of Done
- [ ] Build passes: `cd backend && uv run python -c "from models.document import DocumentResponse"`
- [ ] Tests pass: `cd backend && uv run pytest tests/test_document_service.py -q`
- [ ] No dead code: n/a — no symbols replaced
- [ ] Type check: `cd backend && uv run mypy models/document.py services/document_service.py`
- [ ] Manual check: `GET /api/documents/<test_id>` response body contains `"page_count": <int>`

## Steps
- [ ] Step 1: Add `page_count: int` to `DocumentResponse` in `models/document.py`
- [ ] Step 2: Populate `page_count` from `document.page_count` in `get_document_by_id`
- [ ] Step 3 (teardown): Confirm no dead code (no symbols replaced). Run the type check.

## Code Review
- Dead code removed: n/a — no symbols replaced
- Build status: pass
- Type errors: none
- Unintended side effects: none — the field is additive, existing consumers are unaffected
- Security surface touched: no
- Verdict: ✅ DONE

## Execution Log
- 2026-07-31T09:12Z | claude-code | step 1 | started
- 2026-07-31T09:14Z | claude-code | step 1 | done | import check exit 0
- 2026-07-31T09:15Z | claude-code | step 2 | started
- 2026-07-31T09:21Z | claude-code | step 2 | done | `pytest tests/test_document_service.py -q` 12 passed
- 2026-07-31T09:23Z | claude-code | step 3 | done | mypy clean, 0 symbols to scan
- 2026-07-31T09:24Z | claude-code | plan | done | all 5 DoD items pass

## Notes
(no deviations)
```

### What this example demonstrates

- `Files NOT touched` names the router explicitly, because an additive Pydantic field is not a breaking change. The executing agent knows not to open it.
- `No dead code` reads `n/a` **with the reason**, not blank. A blank field is indistinguishable from a forgotten one.
- The dead-code gate never fires — no symbols were replaced — so the teardown step is light.
- The Execution Log carries evidence per step, not just a status. `12 passed` is what makes it auditable from another harness.

---

## Example 3 — One-file refactor (full plan with the dead-code gate)

> **Task**: extract the price calculation out of `billing_service.py` into a pure `calculate_price()` in `utils/pricing.py`.

### Plan file

```markdown
---
task: Extract price calculation logic to utils/pricing.py
status: planned
created: 2026-07-31
---

# Extract calculate_price() to utils/pricing.py

## Context
- Existing code checked: `_compute_billing_amount` inline in `services/billing_service.py` (lines 84-112). Called only from `BillingService.create_invoice`; an impact query found no other callers.
- Fresh info looked up: n/a
- Git status checked: clean

## Simpler Alternative Considered
Leaving the logic inline and adding tests against `create_invoice` — rejected, the caller needs the pure function for a second call site next sprint

## Surgical Scope
- **Files touched**:
  - `backend/utils/pricing.py` (create, add `calculate_price()`)
  - `backend/services/billing_service.py` (call `calculate_price()`, delete `_compute_billing_amount`)
- **Files NOT touched**: all others
- **Symbols replaced** (→ must delete before done):
  - `_compute_billing_amount` in `services/billing_service.py`
- **Symbols extended** (→ keep):
  - `BillingService.create_invoice` in `services/billing_service.py`

## Definition of Done
- [ ] Build passes: `cd backend && uv run python -c "from services.billing_service import BillingService"`
- [ ] Tests pass: `cd backend && uv run pytest tests/test_billing_service.py -q`
- [ ] No dead code: `_compute_billing_amount` confirmed deleted, 0 references remaining
- [ ] Type check: `cd backend && uv run mypy utils/pricing.py services/billing_service.py`
- [ ] Manual check: n/a — covered by tests

## Steps
- [ ] Step 1: Create `backend/utils/pricing.py` with a typed `calculate_price()` holding the extracted logic
- [ ] Step 2: In `billing_service.py`, import `calculate_price`, replace the `_compute_billing_amount` call, and delete `_compute_billing_amount` in this same step
  - **Dead-code gate**: search for `_compute_billing_amount` → must return 0 results after the deletion
- [ ] Step 3 (teardown): Orphan scan on `_compute_billing_amount`, bounded to that symbol. Confirm 0. Run the build and the type check.

## Code Review
- Dead code removed: yes — `_compute_billing_amount` deleted in step 2, 0 references confirmed
- Build status: pass
- Type errors: none
- Unintended side effects: none — `create_invoice` behavior unchanged, only the code location moved
- Security surface touched: no
- Verdict: ✅ DONE

## Execution Log
- 2026-07-31T11:02Z | claude-code | step 1 | started
- 2026-07-31T11:09Z | claude-code | step 1 | done | import check exit 0
- 2026-07-31T11:10Z | claude-code | step 2 | started
- 2026-07-31T11:18Z | antigravity | step 2 | done | `pytest -q` 31 passed; grep `_compute_billing_amount` → 0 hits
- 2026-07-31T11:22Z | antigravity | step 3 | done | orphan scan 0, mypy clean
- 2026-07-31T11:23Z | antigravity | plan | done | all 5 DoD items pass

## Notes
- Step 2 resumed on Antigravity after the Claude Code session ran out of context. The step was at `[~]`; the diff showed the import added but the old function still present, so it was reverted to `[ ]` and redone cleanly.
```

### What this example demonstrates

- The dead-code gate lives **inside step 2**, not in a separate cleanup step. The symbol is deleted by the step that orphaned it.
- `Symbols replaced` names `_compute_billing_amount` up front, so the executing agent knows from the start that it must disappear.
- `No dead code` is a checkable claim (0 references), not an intention.
- The teardown scan is a safety net bounded to this task's own symbol — never a repo-wide dead-code sweep, which is a different task.
- The Execution Log records a **harness switch mid-plan**. This is the case the whole format exists for: the second harness read the `[~]` marker, reconciled against the diff, and finished the work with no conversation history.

---

## Anti-patterns

| Anti-pattern | Symptom | Correction |
|---|---|---|
| Vague Definition of Done | `- [ ] It works` | An exact command plus a binary criterion |
| Deferred dead code | Step 2 orphans a symbol, step 5 "cleans up" | Delete it in the step that orphaned it |
| Scope drift | The agent refactors an adjacent function while in the file | An explicit `Files NOT touched` list |
| Unverified completion | `✅ DONE` without a command having run | Fresh evidence in the same message as the check-off |
| Missing teardown | The plan ends at the last code step | The last step is always the teardown |
| Machine-local commands | `rtk pnpm build` in the Definition of Done | The bare command — the next harness has no `rtk` |
| Blank review fields | `Type errors:` with nothing after it | Every field gets a value, `n/a` with a reason if needed |
