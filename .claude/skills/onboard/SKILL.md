---
name: onboard
description: Interviews the operator once about a freshly seeded fukuii-project repo and applies the answers directly — branching policy, Dependabot ecosystems, Scala SAST, container scanning, and the pnpm release-age gate. Use when a repo was just created from fukuii-template, or when someone asks to run the per-repo setup decisions in .github/SETUP-CHECKLIST.md. Writes the Branching bullet, uncomments the chosen Dependabot stanzas and workflow triggers, removes the workflows this repo declined, creates a policy-only .npmrc, and sets the repo description and topics. Do NOT use for filling {{PLACEHOLDER}} text, writing AGENTS.md content, repinning action SHAs or pre-commit revs, or onboarding a repo that has already been onboarded.
disable-model-invocation: true
user-invocable: true
model: sonnet
argument-hint: "dry-run"
allowed-tools: Read, Bash(${CLAUDE_SKILL_DIR}/scripts/onboard-preflight.sh*), Bash(.claude/skills/onboard/scripts/onboard-preflight.sh*), Edit(./AGENTS.md), Edit(./.gitignore), Edit(./.npmrc), Edit(./.github/dependabot.yml), Edit(./.github/workflows/semgrep.yml), Edit(./.github/workflows/trivy.yml)
---

# Onboard a seeded repo

Turns the conditional half of `.github/SETUP-CHECKLIST.md` into one interview that
**acts on the answers**. The checklist stays the human-readable record of what the
decisions are and why; this skill is how they get made and applied. If the two ever
disagree, the checklist is right and this skill is stale.

**Why the tool grants are scoped to six files.** A skill checked into a repo can
grant itself broad tool access, and every clone runs it — Anthropic's own guidance
is to *"review the `allowed-tools` of skills checked into a repository before you
run Claude Code there"*, so this one is written to survive that review. It names the
six files it touches and nothing else. They are `Edit(...)` rules even for the file
it *creates*, because Claude Code *"checks file permissions against `Edit(path)` and
`Read(path)` rules only"* — a `Write(...)` path rule is accepted, never consulted,
and warned about at startup (<https://code.claude.com/docs/en/permissions>).
`allowed-tools` never restricts, so this costs nothing but a permission prompt if
the skill ever needs a seventh file — which is the correct outcome, not a bug.
Deleting and pushing metadata are deliberately absent: `git rm` and `gh repo edit`
prompt every time.

## CRITICAL — the three rules that matter

1. **Never delete a file the preflight has not marked `RECOVERABLE`.** Step 1's
   report is the pre-image gate. `UNSAFE` means git holds no recoverable copy, so
   the deletion is irreversible — stop and tell the operator to commit first.
   **The second half of that gate is `"ask": ["Bash(git rm *)"]` in this repo's own
   `.claude/settings.json`, and it is there so the gate travels with the
   template.** Omitting `git rm` from `allowed-tools` is not a gate: `allowed-tools`
   pre-approves, it does not restrict, so on a machine whose settings already allow
   `Bash(git *)` the deletion would run unprompted. An `ask` rule is what actually
   prompts — permission rules are *"evaluated in order: deny, then ask, then allow"*
   and *"a matching ask rule prompts even when a more specific allow rule also
   matches the same call"* (<https://code.claude.com/docs/en/permissions>). Do not
   remove that line to make a run quieter.
2. **Never touch a pinned SHA or a `rev:`.** Action pins in `.github/workflows/*`
   and `rev:` values in `.pre-commit-config.yaml` are supply-chain state, set
   deliberately and audited elsewhere. This skill does not read them, bump them,
   or reformat the lines they sit on.
3. **Ask before acting, once.** Every decision is gathered up front, then applied.
   Do not act on question 1 and then ask question 2.

## 1. Preflight (mechanical — one call, no judgment)

```bash
${CLAUDE_SKILL_DIR}/scripts/onboard-preflight.sh
```

**Run it by that path, unquoted.** Claude Code substitutes `${CLAUDE_SKILL_DIR}` in
both the skill body and its `Bash` `allowed-tools` rules, so the pre-approval
matches whichever directory the session started in
(<https://code.claude.com/docs/en/skills>). Quoting it breaks the match. The
repo-relative form `.claude/skills/onboard/scripts/onboard-preflight.sh` is
pre-approved too, as a fallback for a Claude Code old enough not to substitute the
variable — but it only works **from the repository root**: run from a subdirectory
it neither resolves nor matches the pre-approval. If you end up on that path, say
so and approve the prompt rather than rewriting the command.

Read-only. It reports whether onboarding already ran, what stack markers exist,
whether each deletion target is recoverable, current Dependabot and trigger state,
the `.npmrc` ignore status checked by effect, and the repo's current description
and topics. Pass `--no-remote` to skip its single `gh` network read.

**If the verdict is `ALREADY-ONBOARDED`, stop.** Print the current state and say
onboarding has already run. Re-run a single decision only if the operator names it.

**If the report says `CALIBRATION FAILED`, stop.** Its ignore results are not
trustworthy and the `.npmrc` step depends on them.

**If you edit that script, run `scripts/onboard-preflight.test.sh` first.** It
builds throwaway git repos and asserts the states that are easy to get wrong in the
unsafe direction — a tracked-but-broken symlink, an unstaged `rm`, a half-finished
trigger uncomment. Four of them were live bugs. Every group carries a negative
control, so a check that matches everything fails the suite too.

**If `$ARGUMENTS` contains `dry-run`, do steps 2 and 3 as a written plan and change
nothing.** Name every file that would be edited, created, or removed.

## 2. The interview (contextual — this is the whole point)

Ask with `AskUserQuestion`. **It caps at 4 questions per call and 2-4 options per
question**, so the six decisions take **two calls, back to back, before any edit**.
That is the mechanism's limit, not a change to the design: nothing is applied until
both cards are answered.

Attach the preflight's evidence to each question as the suggested default, and say
what it was. Evidence proposes; the operator decides. A repo may legitimately want
an ecosystem it has no manifest for yet, or refuse one it has.

**Call 1** — four questions, two options each:

| # | Header | Question | Options |
|---|---|---|---|
| 1 | `Branching` | Work directly on `main`, or require topic branches? | `Direct to main` · `Topic branches` |
| 2 | `Scala/JVM` | Is this a Scala or JVM repo? | `Yes` · `No` |
| 3 | `Docker/IaC` | Does this repo build a container image or ship compose/IaC? | `Yes` · `No` |
| 4 | `JS/pnpm` | Is this a JavaScript/pnpm repo? | `Yes` · `No` |

Question 1 is a judgment call, so frame it: solo or multi-contributor, whether CI
or deploys fire from `main`, and how easily a commit reverts. Questions 2-4 each
decide a file, and the option descriptions should say which.

**Call 2** — two questions:

| # | Header | Question | Options |
|---|---|---|---|
| 5 | `Other deps` | Any other Dependabot ecosystems? (`sbt`, `npm` and `docker` follow from 2-4) | `pip` · `gomod` · `cargo` · `None` — `multiSelect: true` |
| 6 | `Repo meta` | Set the repo description and topics now? | `Use the draft below` · `Let me write them` · `Skip` |

Before call 2, draft a one-line description and 3-6 topics from the README and
`AGENTS.md`, and show them, so option 1 is a real choice rather than a blank.
GitHub topics are lowercase, digits and hyphens only.

**If `AskUserQuestion` is unavailable** — it does not exist inside a subagent —
ask all six in one numbered message and wait for one reply. Never guess an answer.

## 3. Apply (mechanical, but each edit is exact)

Work in this order. Report each as done or skipped.

**Uncommenting is one rule, used twice.** In both `dependabot.yml` and the workflow
trigger blocks, an enabled line is the commented line minus exactly the `# ` at
columns 3-4. `  # - package-ecosystem:` becomes `  - package-ecosystem:`, and
`  #   directory:` becomes `    directory:`. Preserve every other character.

1. **Branching → `AGENTS.md`.** Add one bullet under `## Conventions`, in the
   operator's chosen policy, 1-2 sentences, in this exact shape:
   `- **Branching:** …`
   The `**Branching:**` prefix is the sentinel the preflight reads to detect that
   onboarding has run. Do not reword it. This bullet is written on **every** run,
   whichever policy was chosen — that is what makes the sentinel reliable.
2. **Dependabot → `.github/dependabot.yml`.** Uncomment the stanza for each chosen
   ecosystem; leave the others commented. `sbt` follows from a yes on Q2, `docker`
   from Q3, `npm` from Q4, plus anything picked in Q5. Never touch
   `github-actions` — it is unconditional, because every repo has workflows. Every
   stanza keeps its `cooldown` block.
3. **Scala SAST → `.github/workflows/semgrep.yml`.**
   - **Yes:** uncomment the `push` and `pull_request` triggers. The file ships
     `workflow_dispatch`-only, so keeping it is *not* the same as enabling it.
     Mention Scala Steward as the complementary dependency updater.
   - **No:** `git rm .github/workflows/semgrep.yml` — only if the preflight said
     `RECOVERABLE`, or `ABSENT`, in which case it is already done.
4. **Container scanning → `.github/workflows/trivy.yml`.** Same two branches as
   step 3, same pre-image gate.
5. **pnpm gate.** On a **no**, create nothing. On a **yes**, both halves, in order:
   - Write `.npmrc` with `minimum-release-age=10080`. Kebab-case is the form pnpm
     normalizes from `.npmrc`; camelCase is not read there. If the repo needs
     registry auth, it interpolates — `//registry.npmjs.org/:_authToken=${NPM_TOKEN}` —
     never a literal token in a tracked file.
   - **Un-ignore it**: delete the `.npmrc` line from `.gitignore`, and record why
     in the comment above it. An ignored `.npmrc` is invisible to review, and a
     `minimum-release-age=0` line in one silently defeats the gate — tracking it is
     what puts that line in a PR diff. Do **not** write `!/.npmrc`: the leading
     slash re-includes only the root file and leaves a nested workspace `.npmrc`
     hidden, which is the same hole reopened one directory down.
6. **Description and topics.** One call:
   `gh repo edit --description "…" --add-topic a,b,c`
   Skip on a `Skip` answer, or if the preflight reported `gh` missing or
   unauthenticated — say so rather than failing silently.

**Do not commit.** Leave everything in the working tree. The operator has just
chosen a branching policy this run and may have chosen topic branches, so
committing to the current branch could contradict the decision being applied. Say
what to stage.

## 4. Verify (mechanical — required, not optional)

Re-run the preflight. An exit code proves a command ran, not that the repo changed
the way you intended.

Confirm against the answers: the Branching bullet is present, each chosen ecosystem
reads `ACTIVE`, `YAML parse` is `OK`, declined workflows read `removed`, kept ones
read `ACTIVE on push/PR`, and — if `.npmrc` was created — it reports **not** ignored
with calibration still passing. Any mismatch is a finding to report, not to hide.

## 5. Report

State what changed and what was verified. Then, unconditionally:

```
REMOVED (recoverable from commit <sha> until you commit):
  .github/workflows/semgrep.yml   — declined: not a Scala/JVM repo
Restore: git restore --staged --worktree .github/workflows/semgrep.yml
```

**Print this block even when nothing was removed** — "REMOVED: none" is a result.
A deletion the operator does not notice is the failure mode this skill has to
avoid, so name the file, the answer that caused it, and the exact way back.

Close by listing what `/onboard` deliberately did not do: `{{PLACEHOLDER}}` text,
`AGENTS.md` prose, the README template-usage section, action SHAs, and
`pre-commit` `rev:` pins. Those stay in `.github/SETUP-CHECKLIST.md`.
