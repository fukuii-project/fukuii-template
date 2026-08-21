#!/usr/bin/env bash
#
# onboard-preflight.test.sh — regression suite for onboard-preflight.sh.
#
# Run:  .claude/skills/onboard/scripts/onboard-preflight.test.sh
# Exit: 0 all assertions passed · 1 at least one failed
#
# WHY THIS EXISTS. onboard-preflight.sh is the pre-image gate: /onboard refuses
# to delete anything the script has not marked RECOVERABLE, and treats its
# trigger line as proof a kept security workflow actually runs. Four of its
# states were wrong on first review, every one of them failing toward "looks
# fine" — an ABSENT that skipped a real deletion, an "ACTIVE on push/PR" for a
# workflow wired to only one trigger. Those four are the first four groups below.
#
# Each case builds a throwaway git repo under `mktemp -d` and runs the script
# against it. It never reads, writes, or runs anything in the repo it ships in.
#
# EVERY GROUP CARRIES A NEGATIVE CONTROL. An assertion suite that can only
# report "matched" cannot tell a working check from one that matches everything,
# which is the same calibration rule the script itself applies to `git check-ignore`.

# shellcheck disable=SC2016
# SC2016 fires on the assertion labels and expected-value patterns below: the
# backticks are markdown from the report being asserted against, not command
# substitution. Disabled file-wide, as in the script under test, so real findings
# stay visible.
set -uo pipefail   # deliberately NOT -e: an assertion must fail without aborting

HERE="$(cd "$(dirname "$0")" && pwd)"
SUT="$HERE/onboard-preflight.sh"
[ -x "$SUT" ] || { printf 'cannot find an executable onboard-preflight.sh next to this test\n' >&2; exit 1; }

# Identity via env, so the suite does not depend on — or touch — git config.
export GIT_AUTHOR_NAME=onboard-test GIT_AUTHOR_EMAIL=onboard@test.invalid
export GIT_COMMITTER_NAME=onboard-test GIT_COMMITTER_EMAIL=onboard@test.invalid

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/onboard-preflight-test.XXXXXX")"
trap 'rm -rf "$TMPROOT"' EXIT

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n         expected: %s\n' "$1" "$2"; }

has()  { if printf '%s\n' "$3" | grep -Eq "$2"; then ok "$1"; else bad "$1" "match /$2/"; fi; }
hasnt(){ if printf '%s\n' "$3" | grep -Eq "$2"; then bad "$1" "NO match /$2/"; else ok "$1"; fi; }

# Section slicers — the same path appears in more than one table, so assert
# against the section that owns the verdict rather than the whole report.
sec() { printf '%s\n' "$2" | sed -n "/^## $1\./,/^## /p"; }
secph() { printf '%s\n' "$1" | sed -n '/^## Placeholders/,$p'; }

REPO=""
mkrepo() { # mkrepo <name> — a minimal seeded-repo skeleton, uncommitted
  REPO="$TMPROOT/$1"
  mkdir -p "$REPO/.github/workflows"
  git init -q -b main "$REPO" >/dev/null 2>&1
  printf '.env\nnode_modules/\n'                 > "$REPO/.gitignore"
  printf '# fixture\n'                           > "$REPO/README.md"
  printf '# fixture\n\n## Conventions\n'         > "$REPO/AGENTS.md"
  printf 'name: semgrep\non:\n  workflow_dispatch:\n  # push:\n  #   branches: [main]\n  # pull_request:\n' \
                                                 > "$REPO/.github/workflows/semgrep.yml"
  printf 'name: trivy\non:\n  workflow_dispatch:\n  # push:\n  #   branches: [main]\n  # pull_request:\n' \
                                                 > "$REPO/.github/workflows/trivy.yml"
  printf 'version: 2\nupdates:\n  - package-ecosystem: "github-actions"\n    directory: "/"\n  # - package-ecosystem: "npm"\n  #   directory: "/"\n' \
                                                 > "$REPO/.github/dependabot.yml"
}
commitall() {
  git -C "$REPO" add -A >/dev/null 2>&1
  git -C "$REPO" -c commit.gpgsign=false commit -q -m fixture >/dev/null 2>&1
}
run() { ( cd "$REPO" && "$SUT" --no-remote 2>&1 ); }

SEM='semgrep\.yml'

# ---------------------------------------------------------------------------
printf '\n== deletion safety: tracked is decided before on-disk existence ==\n'

mkrepo d1; commitall
O="$(run)"; S="$(sec 3 "$O")"
has   'D1 clean tracked file matching HEAD -> RECOVERABLE' "$SEM.*RECOVERABLE" "$S"
hasnt 'D1 negative control: not UNSAFE'                    "$SEM.*UNSAFE"      "$S"

# The bug: `[ -e ]` follows the link, so a dangling one read as ABSENT and the
# deletion was silently skipped. `git rm` on it succeeds and has real work to do.
mkrepo d2
rm "$REPO/.github/workflows/semgrep.yml"
ln -s /nonexistent/target "$REPO/.github/workflows/semgrep.yml"
commitall
O="$(run)"; S="$(sec 3 "$O")"
hasnt 'D2 tracked BROKEN SYMLINK -> not ABSENT'  "$SEM.*ABSENT"      "$S"
has   'D2 tracked broken symlink -> RECOVERABLE' "$SEM.*RECOVERABLE" "$S"

# The bug: same shape, different cause — a worktree deletion nobody staged.
mkrepo d3; commitall
rm "$REPO/.github/workflows/semgrep.yml"
O="$(run)"; S="$(sec 3 "$O")"
hasnt 'D3 unstaged `rm` of a tracked file -> not ABSENT' "$SEM.*ABSENT"      "$S"
has   'D3 unstaged `rm` -> RECOVERABLE (HEAD holds it)'  "$SEM.*RECOVERABLE" "$S"

mkrepo d4; commitall
git -C "$REPO" rm -q --cached .github/workflows/semgrep.yml >/dev/null 2>&1
O="$(run)"; S="$(sec 3 "$O")"
has 'D4 untracked file on disk -> UNSAFE' "$SEM.*UNSAFE" "$S"

mkrepo d5
git -C "$REPO" add -A >/dev/null 2>&1        # staged, never committed: no HEAD
O="$(run)"; S="$(sec 3 "$O")"
has 'D5 repo with no commit -> UNSAFE' "$SEM.*UNSAFE" "$S"

mkrepo d6; commitall
printf '\n# local edit\n' >> "$REPO/.github/workflows/semgrep.yml"
O="$(run)"; S="$(sec 3 "$O")"
has 'D6 uncommitted local changes -> UNSAFE' "$SEM.*UNSAFE" "$S"

mkrepo d7
rm "$REPO/.github/workflows/semgrep.yml"
commitall                                     # HEAD exists, without semgrep.yml
printf 'name: semgrep\non:\n  workflow_dispatch:\n' > "$REPO/.github/workflows/semgrep.yml"
git -C "$REPO" add .github/workflows/semgrep.yml >/dev/null 2>&1
O="$(run)"; S="$(sec 3 "$O")"
has 'D7 staged but never committed -> UNSAFE' "$SEM.*UNSAFE" "$S"

mkrepo d8; commitall
git -C "$REPO" rm -q .github/workflows/semgrep.yml >/dev/null 2>&1
O="$(run)"; S="$(sec 3 "$O")"
has 'D8 deletion already staged -> ABSENT (genuinely done)' "$SEM.*ABSENT" "$S"

# ---------------------------------------------------------------------------
printf '\n== workflow triggers: push and pull_request are read independently ==\n'

mkrepo t1; commitall
O="$(run)"; S="$(sec 4 "$O")"
has 'T1 both commented -> dispatch-only' "$SEM.*dispatch-only" "$S"

mkrepo t2
printf 'name: semgrep\non:\n  workflow_dispatch:\n  push:\n    branches: [main]\n  pull_request:\n' \
  > "$REPO/.github/workflows/semgrep.yml"
commitall
O="$(run)"; S="$(sec 4 "$O")"
has 'T2 both uncommented -> ACTIVE on push + pull_request' "$SEM.*ACTIVE on push \+ pull_request" "$S"

# The bug, direction 1: push done, pull_request forgotten, reported as fully on.
mkrepo t3
printf 'name: semgrep\non:\n  workflow_dispatch:\n  push:\n    branches: [main]\n  # pull_request:\n' \
  > "$REPO/.github/workflows/semgrep.yml"
commitall
O="$(run)"; S="$(sec 4 "$O")"
has   'T3 push only -> PARTIAL'                  "$SEM.*PARTIAL"  "$S"
hasnt 'T3 negative control: not reported ACTIVE' "$SEM.*\| ACTIVE" "$S"

# The bug, direction 2: pull_request done, push forgotten, reported as fully off.
mkrepo t4
printf 'name: semgrep\non:\n  workflow_dispatch:\n  # push:\n  #   branches: [main]\n  pull_request:\n' \
  > "$REPO/.github/workflows/semgrep.yml"
commitall
O="$(run)"; S="$(sec 4 "$O")"
has   'T4 pull_request only -> PARTIAL'                 "$SEM.*PARTIAL"       "$S"
hasnt 'T4 negative control: not reported dispatch-only' "$SEM.*dispatch-only" "$S"

# ---------------------------------------------------------------------------
printf '\n== placeholders: tracked-and-unignored only, prose mentions excluded ==\n'

mkrepo p1
mkdir -p "$REPO/node_modules/dep" "$REPO/.claude/skills/onboard" "$REPO/.github"
printf 'install with {{PACKAGE}}\n' > "$REPO/node_modules/dep/README.md"
printf 'never fills {{PLACEHOLDER}} text\n' > "$REPO/.claude/skills/onboard/SKILL.md"
printf 'replace every `{{PLACEHOLDER}}`\n' > "$REPO/.github/SETUP-CHECKLIST.md"
printf '# {{REPO_NAME}}\n' > "$REPO/README.md"
commitall
O="$(run)"; S="$(secph "$O")"
hasnt 'P1 ignored node_modules mustache -> not listed'   'node_modules'        "$S"
hasnt 'P1 skill own SKILL.md prose mention -> not listed' 'SKILL\.md'          "$S"
hasnt 'P1 SETUP-CHECKLIST prose mention -> not listed'    'SETUP-CHECKLIST\.md' "$S"
has   'P1 positive control: real {{REPO_NAME}} IS listed' 'README\.md'         "$S"

# ---------------------------------------------------------------------------
printf '\n== sentinel: the markdown variants a human actually writes ==\n'

for v in '- **Branching:** direct to main' '- **Branching**: direct to main' '* **Branching:** direct to main'; do
  mkrepo s1
  printf '# fixture\n\n## Conventions\n%s\n' "$v" > "$REPO/AGENTS.md"
  commitall
  has "S: '$v' -> ALREADY-ONBOARDED" 'ALREADY-ONBOARDED' "$(run)"
done
mkrepo s4; commitall
has 'S negative control: no bullet -> NOT-ONBOARDED' 'NOT-ONBOARDED' "$(run)"

# ---------------------------------------------------------------------------
printf '\n== dependabot: every valid YAML quoting form for one value ==\n'

deps() { # deps <ecosystem-line>
  mkrepo e1
  printf 'version: 2\nupdates:\n  %s\n    directory: "/"\n' "$1" > "$REPO/.github/dependabot.yml"
  commitall
  sec 5 "$(run)"
}
has 'E1 single-quoted `npm` -> ACTIVE' '`npm` \| ACTIVE'  "$(deps "- package-ecosystem: 'npm'")"
has 'E2 bare `npm` -> ACTIVE'          '`npm` \| ACTIVE'  "$(deps '- package-ecosystem: npm')"
has 'E3 double-quoted `npm` -> ACTIVE' '`npm` \| ACTIVE'  "$(deps '- package-ecosystem: "npm"')"
has 'E4 negative control: cargo absent from file' '`cargo` \| absent from file' "$(deps '- package-ecosystem: npm')"

mkrepo e5; commitall
has 'E5 commented stanza -> commented' '`npm` \| commented' "$(sec 5 "$(run)")"

# ---------------------------------------------------------------------------
printf '\n== hard stops both exit 2 ==\n'

status_is() { # status_is <name> <expected> <actual>
  if [ "$3" = "$2" ]; then ok "$1"; else bad "$1" "exit status $2, got $3"; fi
}

mkrepo x1; commitall
( cd "$REPO" && "$SUT" --bogus ) >/dev/null 2>&1
status_is 'X1 unknown argument -> exit 2' 2 "$?"

mkdir -p "$TMPROOT/notarepo"
( cd "$TMPROOT/notarepo" && GIT_CEILING_DIRECTORIES="$TMPROOT" "$SUT" --no-remote ) >/dev/null 2>&1
status_is 'X2 outside a git work tree -> exit 2' 2 "$?"

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
