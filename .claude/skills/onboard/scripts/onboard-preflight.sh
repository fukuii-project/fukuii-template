#!/usr/bin/env bash
#
# onboard-preflight — read-only state report for the /onboard skill.
#
# Gathers everything /onboard needs to (a) ask its questions with the repo's own
# evidence attached and (b) verify afterwards that what it did took effect.
#
# READ-ONLY BY CONTRACT. It never writes, deletes, stages, or reformats anything.
# That is what lets it be the independent check on /onboard's own edits: run it
# before the interview for the starting state, and again after for the effects.
# A checker that also fixes has no independent report left to read.
#
# Usage:  .claude/skills/onboard/scripts/onboard-preflight.sh [--no-remote]
#         --no-remote   skip the single `gh repo view` call (the only network read)
#
# Exit:   0  report produced — including when the report is all bad news
#         2  cannot run — not inside a git work tree, or an unknown argument
#
# Portability: bash 3.2+, git, POSIX grep. `python3`+PyYAML and `gh` are optional;
# their absence is reported as UNVERIFIED rather than guessed around.

# shellcheck disable=SC2016
# SC2016 fires on every printf format string below, because they are markdown:
# the backticks are code spans in the report, not command substitution. Disabled
# file-wide and deliberately, so the linter's real findings stay visible.
set -euo pipefail

WITH_REMOTE=1
case "${1:-}" in
  --no-remote) WITH_REMOTE=0 ;;
  "") ;;
  *)
    printf 'onboard-preflight: unknown argument %s\n' "$1" >&2
    exit 2
    ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$ROOT" ]; then
  printf 'onboard-preflight: not inside a git work tree.\n' >&2
  printf 'This is a hard stop, not a warning: every file /onboard deletes is\n' >&2
  printf 'recoverable only because git holds the pre-image. No git, no pre-image.\n' >&2
  exit 2
fi
cd "$ROOT"

have() { command -v "$1" >/dev/null 2>&1; }

# `-e` follows symlinks, so a DANGLING symlink reads as absent even though the
# link itself is right there and is tracked. `-L` catches that case.
exists_path() { [ -e "$1" ] || [ -L "$1" ]; }

# Tracked plus untracked-but-not-ignored. Sees manifests a fresh repo has not
# committed yet, and skips vendored trees (node_modules, target/, .venv) because
# those are already ignored.
FILES="$(git ls-files -co --exclude-standard)"
match() { printf '%s\n' "$FILES" | grep -Eq "$1"; }

if git rev-parse --verify -q HEAD >/dev/null 2>&1; then
  HAS_HEAD=yes
  HEAD_SHA="$(git rev-parse --short HEAD)"
else
  HAS_HEAD=no
  HEAD_SHA="(no commit yet)"
fi

SEMGREP=".github/workflows/semgrep.yml"
TRIVY=".github/workflows/trivy.yml"
DEPENDABOT=".github/dependabot.yml"

printf '# onboard preflight\n\n'
printf 'Repo root: `%s`\n' "$ROOT"
printf 'Pre-image commit: `%s`\n\n' "$HEAD_SHA"

# ---------------------------------------------------------------- already run?
printf '## 1. Has onboarding already run?\n\n'
BRANCHING_BULLET=no
# Tolerates the natural markdown variants — `-` or `*` bullet, colon inside or
# outside the bold span. A sentinel that misses one fails SILENTLY: the interview
# re-asks all six questions and a second Branching bullet lands in AGENTS.md.
if [ -f AGENTS.md ] && grep -Eq '^[[:space:]]*[-*][[:space:]]*\*\*Branching:?\*\*:?' AGENTS.md; then
  BRANCHING_BULLET=yes
fi
printf '| Signal | State |\n|---|---|\n'
printf '| Branching bullet in AGENTS.md | %s |\n' "$BRANCHING_BULLET"
# present/absent, never "removed": a repo that never had the file did not have it
# deleted. "REMOVED" is reserved for what /onboard actually deleted this run.
printf '| `%s` | %s |\n' "$SEMGREP" "$(exists_path "$SEMGREP" && echo present || echo absent)"
printf '| `%s` | %s |\n' "$TRIVY" "$(exists_path "$TRIVY" && echo present || echo absent)"
printf '| `.npmrc` | %s |\n' "$(exists_path .npmrc && echo present || echo absent)"
printf '\n'
if [ "$BRANCHING_BULLET" = yes ]; then
  printf '**VERDICT: ALREADY-ONBOARDED.** The Branching bullet is the sentinel — it is\n'
  printf 'the one edit every answer produces, and /onboard writes it LAST, so its\n'
  printf 'presence means the apply phase FINISHED rather than merely started.\n'
  printf 'Do not re-run the interview. Report current state and stop unless the operator\n'
  printf 'explicitly asks to redo a specific decision.\n\n'
else
  printf '**VERDICT: NOT-ONBOARDED.** Proceed with the interview.\n\n'
fi

# ------------------------------------------------------------- stack evidence
printf '## 2. Stack evidence (attach to the questions; do not decide from it)\n\n'
printf 'Evidence is a default to offer, never an answer to assume. A repo can\n'
printf 'legitimately want an ecosystem it has no manifest for yet, or refuse one it does.\n\n'
printf '| Question | Marker found | Evidence |\n|---|---|---|\n'

ev() { # ev <label> <regex>
  if match "$2"; then
    printf '| %s | YES | `%s` |\n' "$1" "$(printf '%s\n' "$FILES" | grep -E "$2" | head -3 | tr '\n' ' ')"
  else
    printf '| %s | no | — |\n' "$1"
  fi
}
ev 'Scala/JVM (semgrep, sbt)' '(^|/)(build\.sbt|build\.gradle(\.kts)?|pom\.xml)$|\.scala$'
ev 'Docker/IaC (trivy, docker)' '(^|/)(Dockerfile|Containerfile|compose\.ya?ml|docker-compose[^/]*\.ya?ml)$|\.tf$'
ev 'JS/pnpm (.npmrc, npm)' '(^|/)(package\.json|pnpm-lock\.yaml|package-lock\.json|yarn\.lock)$'
ev 'Python (pip)' '(^|/)(requirements[^/]*\.txt|pyproject\.toml|setup\.py|Pipfile)$'
ev 'Go (gomod)' '(^|/)go\.mod$'
ev 'Rust (cargo)' '(^|/)Cargo\.toml$'
printf '\n'

# ----------------------------------------------------------- deletion safety
printf '## 3. Deletion safety (the pre-image gate)\n\n'
printf 'A tracked file whose pre-image is in HEAD is a REVERSIBLE write: git holds a\n'
printf 'copy. Anything else is IRREVERSIBLE and /onboard must refuse to delete it.\n\n'
printf 'TRACKED IS CHECKED BEFORE ON-DISK EXISTENCE, and that order is the whole point.\n'
printf 'A file test is the wrong first question: a tracked-but-broken symlink and a\n'
printf 'tracked file removed with plain `rm` both read as absent to it, while `git rm`\n'
printf 'on either one still succeeds and still has real work to do. Reporting ABSENT\n'
printf 'there tells /onboard to skip a step it must not skip, and the skipped deletion\n'
printf 'is then never staged and never reported.\n\n'
printf '| File | Verdict | Why |\n|---|---|---|\n'

delete_safety() {
  local path="$1"
  local tracked=no exists=no

  if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    tracked=yes
  fi
  if exists_path "$path"; then
    exists=yes
  fi

  if [ "$tracked" != yes ]; then
    if [ "$exists" = yes ]; then
      printf '| `%s` | **UNSAFE** | untracked — deletion would be unrecoverable |\n' "$path"
    else
      printf '| `%s` | ABSENT | not tracked and not on disk — nothing to delete |\n' "$path"
    fi
    return
  fi

  # Tracked from here down. `$exists` is still consulted, but only to tell a
  # recoverable already-deleted worktree apart from a modified one — never to
  # short-circuit to ABSENT.
  if [ "$HAS_HEAD" != yes ]; then
    printf '| `%s` | **UNSAFE** | repo has no commit — git holds no pre-image |\n' "$path"
    return
  fi
  if ! git cat-file -e "HEAD:$path" 2>/dev/null; then
    printf '| `%s` | **UNSAFE** | staged but not in HEAD `%s` — git holds no pre-image |\n' "$path" "$HEAD_SHA"
    return
  fi
  if ! git diff --quiet HEAD -- "$path"; then
    if [ "$exists" = no ] && git diff --quiet --cached HEAD -- "$path"; then
      printf '| `%s` | RECOVERABLE | worktree copy already deleted but NOT staged; HEAD `%s` holds it and `git rm` stages the deletion |\n' "$path" "$HEAD_SHA"
      return
    fi
    printf '| `%s` | **UNSAFE** | uncommitted local changes would be lost |\n' "$path"
    return
  fi
  printf '| `%s` | RECOVERABLE | tracked, matches HEAD `%s` |\n' "$path" "$HEAD_SHA"
}
delete_safety "$SEMGREP"
delete_safety "$TRIVY"
printf '\nRestore command for a RECOVERABLE file removed with `git rm`:\n'
printf '`git restore --staged --worktree <path>`\n\n'

# -------------------------------------------------------------- trigger state
printf '## 4. Conditional workflow triggers\n\n'
printf 'Both files ship with `push`/`pull_request` COMMENTED OUT — `workflow_dispatch`\n'
printf 'only. "Keep it" is therefore not the same as "enable it": a yes answer has to\n'
printf 'uncomment the triggers or the workflow never runs on a push or a PR.\n\n'
printf '| File | Triggers |\n|---|---|\n'
# Each trigger is read on its own line. Inferring `pull_request` from the `push:`
# line is wrong in BOTH directions — a half-finished uncomment reads as fully
# enabled, or as fully disabled — and /onboard's verify step treats this string as
# proof that a kept security workflow actually runs. PARTIAL is a failure, not a
# pass: a scanner firing on one trigger while reporting success is the bad case.
trigger_one() { # trigger_one <file> <trigger> -> active | commented | missing
  if grep -Eq "^[[:space:]]*${2}:" "$1"; then
    printf 'active'
  elif grep -Eq "^[[:space:]]*#[[:space:]]*${2}:" "$1"; then
    printf 'commented'
  else
    printf 'missing'
  fi
}

trigger_state() {
  local path="$1" push pr
  if ! exists_path "$path"; then
    printf '| `%s` | (file absent) |\n' "$path"
    return
  fi
  push="$(trigger_one "$path" push)"
  pr="$(trigger_one "$path" pull_request)"
  if [ "$push" = active ] && [ "$pr" = active ]; then
    printf '| `%s` | ACTIVE on push + pull_request |\n' "$path"
  elif [ "$push" = active ] || [ "$pr" = active ]; then
    printf '| `%s` | **PARTIAL** — push %s, pull_request %s |\n' "$path" "$push" "$pr"
  elif [ "$push" = commented ] || [ "$pr" = commented ]; then
    printf '| `%s` | dispatch-only — push %s, pull_request %s |\n' "$path" "$push" "$pr"
  else
    printf '| `%s` | unrecognized — read the file before editing |\n' "$path"
  fi
}
trigger_state "$SEMGREP"
trigger_state "$TRIVY"
printf '\n'

# ---------------------------------------------------------------- dependabot
printf '## 5. Dependabot ecosystems\n\n'
if [ ! -e "$DEPENDABOT" ]; then
  printf '`%s` is MISSING — stop and report; do not recreate it here.\n\n' "$DEPENDABOT"
else
  printf '| Ecosystem | State |\n|---|---|\n'
  for eco in github-actions sbt npm pip gomod cargo docker; do
    # `"npm"`, `'npm'` and bare `npm` are all valid YAML for the same value, so
    # tolerate all three. The trailing class stops a short name matching a longer
    # one. Reporting a present ecosystem as "absent from file" would send
    # /onboard to uncomment a stanza that is already live.
    ECO_RE="package-ecosystem:[[:space:]]*[\"']?${eco}([\"'[:space:]]|\$)"
    if grep -Eq "^[[:space:]]*-[[:space:]]*${ECO_RE}" "$DEPENDABOT"; then
      printf '| `%s` | ACTIVE |\n' "$eco"
    elif grep -Eq "^[[:space:]]*#[[:space:]]*-[[:space:]]*${ECO_RE}" "$DEPENDABOT"; then
      printf '| `%s` | commented |\n' "$eco"
    else
      printf '| `%s` | absent from file |\n' "$eco"
    fi
  done
  printf '\n'
  if have python3 && python3 -c 'import yaml' >/dev/null 2>&1; then
    if python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$DEPENDABOT" >/dev/null 2>&1; then
      printf 'YAML parse: **OK**\n\n'
    else
      printf 'YAML parse: **FAILED** — the file is not valid YAML. Fix before continuing.\n\n'
    fi
  else
    printf 'YAML parse: UNVERIFIED (no python3 + PyYAML here). `pre-commit run check-yaml\n'
    printf '--all-files` is the other way to settle it.\n\n'
  fi
fi

# ------------------------------------------------------- npmrc / ignore state
printf '## 6. pnpm release-age gate\n\n'
printf 'Checked BY EFFECT with `git check-ignore --no-index`, never by reading the\n'
printf 'patterns, and calibrated against one path that must be ignored and one that\n'
printf 'must not. An ignore check that cannot report "not ignored" proves nothing.\n\n'

ignored() { git check-ignore --no-index -q -- "$1"; }

CAL_OK=yes
ignored .env || CAL_OK=no        # must be ignored
! ignored README.md || CAL_OK=no # must NOT be ignored

if [ "$CAL_OK" != yes ]; then
  printf '**CALIBRATION FAILED** — the control paths did not behave as expected, so the\n'
  printf 'result below is not trustworthy. Investigate `.gitignore` before acting.\n\n'
fi
printf '| Check | Result |\n|---|---|\n'
printf '| calibration (`.env` ignored, `README.md` not) | %s |\n' "$CAL_OK"
printf '| `.npmrc` exists | %s |\n' "$([ -e .npmrc ] && echo yes || echo no)"
if ignored .npmrc; then
  printf '| `.npmrc` ignored by git | YES — invisible to review |\n'
else
  printf '| `.npmrc` ignored by git | no — reviewable in a PR diff |\n'
fi
if [ -e .npmrc ]; then
  if grep -Eq '^[[:space:]]*minimum-release-age[[:space:]]*=' .npmrc; then
    printf '| `minimum-release-age` present | yes |\n'
  else
    printf '| `minimum-release-age` present | **no** |\n'
  fi
  if grep -Eq '_authToken[[:space:]]*=[[:space:]]*[^$[:space:]]' .npmrc; then
    printf '| literal auth token | **PRESENT — STOP, rotate it** |\n'
  else
    printf '| literal auth token | none detected |\n'
  fi
fi
printf '\n'
if have pnpm; then
  printf 'Resolved gate value (`pnpm config get minimumReleaseAge`): `%s`\n' \
    "$(pnpm config get minimumReleaseAge 2>/dev/null || echo '(unreadable)')"
  printf '\nThe resolved value is the only one that says what pnpm will do; the file only\n'
  printf 'says what one file claims.\n\n'
else
  printf 'Resolved gate value: UNVERIFIED (no `pnpm` on this machine).\n\n'
fi

# ------------------------------------------------------------- repo metadata
printf '## 7. Repo description and topics\n\n'
if [ "$WITH_REMOTE" = 0 ]; then
  printf 'Skipped (`--no-remote`).\n\n'
elif ! have gh; then
  printf 'UNVERIFIED — `gh` is not installed. Set the description and topics in the\n'
  printf 'GitHub web UI instead.\n\n'
elif ! gh auth status >/dev/null 2>&1; then
  printf 'UNVERIFIED — `gh` is installed but not authenticated (`gh auth login`).\n\n'
else
  META="$(gh repo view --json nameWithOwner,description,repositoryTopics \
    --jq '[.nameWithOwner, (.description // ""), ([.repositoryTopics[]?.name] | join(" "))] | @tsv' \
    2>/dev/null || true)"
  if [ -z "$META" ]; then
    printf 'UNVERIFIED — `gh repo view` returned nothing (no remote, or no access).\n\n'
  else
    printf '| Field | Current value |\n|---|---|\n'
    printf '| repo | `%s` |\n' "$(printf '%s' "$META" | cut -f1)"
    printf '| description | %s |\n' "$(printf '%s' "$META" | cut -f2 | sed 's/^$/(empty)/')"
    printf '| topics | %s |\n\n' "$(printf '%s' "$META" | cut -f3 | sed 's/^$/(none)/')"
  fi
fi

printf '## Placeholders still unfilled\n\n'
# Scanned over `git ls-files -co --exclude-standard`, like every other check in
# this script, and NOT with `grep -r .`: a JS repo with node_modules installed
# reports third-party README mustache syntax otherwise, at real walk cost.
#
# The literal token `{{PLACEHOLDER}}` is excluded because this skill's own files
# and `.github/SETUP-CHECKLIST.md` carry it as PROSE — it is the NAME of the thing
# they say /onboard does not fill — and both ship in every seeded repo. Listing
# them on every run is a permanent false positive, which teaches the reader to
# skip the section and miss the real ones.
SKILL_DIR_REL=".claude/skills/onboard"
PH=""
while IFS= read -r -d '' phf; do
  case "$phf" in "$SKILL_DIR_REL"/*) continue ;; esac
  PH_HITS="$(grep -oE '\{\{[A-Za-z0-9_ -]+\}\}' "$phf" 2>/dev/null | grep -vFx '{{PLACEHOLDER}}' || true)"
  if [ -n "$PH_HITS" ]; then
    PH="${PH}${phf}
"
  fi
done < <(git ls-files -z -c -o --exclude-standard -- '*.md')
PH="$(printf '%s' "$PH" | sed '/^$/d' | sort || true)"
if [ -z "$PH" ]; then
  printf 'None.\n'
else
  printf 'These still carry `{{PLACEHOLDER}}` text. `/onboard` does NOT fill them —\n'
  printf 'that is the setup checklist'"'"'s job. Listed so the summary can say so.\n\n'
  printf '%s\n' "$PH" | sed 's/^/- `/; s/$/`/'
fi
printf '\n'
