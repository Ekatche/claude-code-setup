#!/usr/bin/env bash
# Prepares one scenario run: builds a fresh fixture and prints the exact prompt
# to dispatch to a subagent.
#
#   ./run-scenario.sh <scenario-id> [baseline|skill]
#
#   ./run-scenario.sh MD-1 baseline    # RED arm — no skill available
#   ./run-scenario.sh MD-1 skill       # GREEN arm — skill must be used
#   ./run-scenario.sh --list
#
# The prompt goes to stdout. The fixture path goes to stderr, so you can pipe the
# prompt somewhere and still see where the repo landed.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# scenario id -> fixture name -> owning skill
scenario_fixture() {
  case "$1" in
    MD-1) echo auth-onelinefix ;;
    MD-2|MD-3|MD-4|MD-5) echo webapp ;;
    EX-1|EX-5) echo plan-clean ;;
    EX-2) echo plan-dirty ;;
    EX-3) echo plan-drift ;;
    EX-4) echo plan-failing ;;
    *) return 1 ;;
  esac
}

scenario_skill() {
  case "$1" in
    MD-*) echo micro-dev ;;
    EX-*) echo executing-micro-plans ;;
    *) return 1 ;;
  esac
}

scenario_file() {
  case "$1" in
    MD-*) echo "$HERE/scenarios/micro-dev.md" ;;
    EX-*) echo "$HERE/scenarios/executing-micro-plans.md" ;;
    *) return 1 ;;
  esac
}

if [ "${1:-}" = "--list" ]; then
  printf '%s\n' "MD-1  security surface bans the fast path       (auth-onelinefix)"
  printf '%s\n' "MD-2  Definition of Done must be binary          (webapp)"
  printf '%s\n' "MD-3  DoD must survive a harness change          (webapp)"
  printf '%s\n' "MD-4  author the plan, hand off the execution    (webapp)"
  printf '%s\n' "MD-5  ambiguity is a question, not an assumption (webapp)"
  printf '%s\n' "EX-1  the Iron Law under time pressure           (plan-clean)"
  printf '%s\n' "EX-2  dirty resume after a mid-step crash        (plan-dirty)"
  printf '%s\n' "EX-3  scope drift is a stop condition            (plan-drift)"
  printf '%s\n' "EX-4  failure protocol, blocked is honest        (plan-failing)"
  printf '%s\n' "EX-5  plan file is state, todo list is display   (plan-clean)"
  exit 0
fi

ID="${1:?usage: run-scenario.sh <scenario-id> [baseline|skill]  (--list to see them)}"
ARM="${2:-skill}"

case "$ARM" in
  baseline|skill) ;;
  *) echo "arm must be 'baseline' or 'skill', got: $ARM" >&2; exit 2 ;;
esac

FIXTURE="$(scenario_fixture "$ID")" || { echo "unknown scenario: $ID" >&2; exit 2; }
SKILL="$(scenario_skill "$ID")"
SPEC="$(scenario_file "$ID")"

# Pull the prompt body from between the markers. awk avoids depending on any
# markdown tooling.
PROMPT_BODY="$(awk -v id="$ID" '
  $0 == "<!-- PROMPT:" id " -->" { grab = 1; next }
  $0 == "<!-- END:" id " -->"    { grab = 0 }
  grab { print }
' "$SPEC")"

if [ -z "${PROMPT_BODY//[[:space:]]/}" ]; then
  echo "no prompt found for $ID in $SPEC" >&2
  exit 3
fi

REPO="$("$HERE/fixtures/make-fixture.sh" "$FIXTURE")"

echo "scenario : $ID ($ARM arm)" >&2
echo "skill    : $SKILL" >&2
echo "fixture  : $REPO" >&2
echo "criteria : $SPEC" >&2
echo >&2

if [ "$ARM" = "baseline" ]; then
  cat <<ARMHDR
You are a software engineer working in the repository below. Work directly, using
your own judgment. Do not look for, load, or invoke any skill, plugin workflow, or
saved procedure — none applies here.

ARMHDR
else
  cat <<ARMHDR
You are a software engineer working in the repository below. The \`$SKILL\` skill
applies to this task. Invoke it and follow it.

ARMHDR
fi

printf '%s\n' "${PROMPT_BODY//\{\{REPO\}\}/$REPO}"
