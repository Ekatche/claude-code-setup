# Harness Map — executing-micro-plans

Skills speak in actions. This table resolves each action to the literal tool on each harness.

| Action | Claude Code | Antigravity (`agy`) | Gemini CLI |
|---|---|---|---|
| Harness id for the Execution Log | `claude-code` | `antigravity` | `gemini-cli` |
| Read a file | `Read` | file-read tool | file-read tool |
| Create a file | `Write` | `write_to_file` | file-write tool |
| Edit a file (toggle `[ ]`→`[~]`→`[x]`) | `Edit` | `replace_file_content` / `multi_replace_file_content` | file-edit tool |
| Run a shell command | `Bash` | shell-execution tool | shell-execution tool |
| Ask the user and wait | `AskUserQuestion` | no structured tool — ask in the chat reply, then wait | same as Antigravity |
| Visible progress tracking | `TodoWrite`, mirrored from the plan file | task artifact: `write_to_file` with `IsArtifact: true`, `ArtifactMetadata.ArtifactType: "task"` | none — the plan file is the tracker |
| Dispatch a subagent (exception only) | `Task` | `invoke_subagent`, `TypeName: research` for read-only | n/a — run inline |

## The mirroring rule

`TodoWrite` and Antigravity task artifacts are **displays**, never state.

1. Edit the plan file first.
2. Then update the display.
3. On any disagreement between the two, the plan file wins — re-sync the display from the file, never the reverse.

A session that updated the todo list but not the plan file has produced no durable progress. The next harness sees nothing.

## Tooling that may be absent

`mgrep`, `rtk`, `code-review-graph`, `semgrep` are local accelerants on one specific machine, not requirements. On a harness or machine where they are not installed, fall back to native grep/glob plus targeted reads. What is portable is the ordering principle — search cheap before reading whole files — not the tool names.

Never put a machine-specific wrapper into a plan's `Definition of Done`. Write `pnpm build`, not `rtk pnpm build`. The DoD must be runnable by whoever picks the plan up.

## Timestamps

Always read the clock from the shell, never from model memory:

```bash
date -u +%Y-%m-%dT%H:%MZ
```

Wrong timestamps make the Execution Log unusable for reconciliation, which is its only job.
