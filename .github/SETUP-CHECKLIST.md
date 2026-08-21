# New-repo setup checklist

## Security: what's automatic vs what this repo adds
The **org Security Configuration** (`fukuii-project-org-config-1`) already **enforces** the common
baseline on every repo — **secret scanning + push protection, CodeQL, Dependabot alerts + security
updates** — inherited, nothing to enable per repo.

This repo fills the **gaps the org baseline can't reach**, by stack. Every row below marked
*conditional* is a decision, not a default: most repos need some of these and not others, and the
**Per repo** checklist turns each one into an explicit yes/no with a stated action for both answers.

| Gap the org config misses | Applies to | Action |
|---|---|---|
| Local pre-commit edge (secrets **and** Actions hardening — org scans server-side + doesn't audit workflows) | all | `pipx install pre-commit && pre-commit install` (gitleaks + zizmor + actionlint) |
| Dependabot **version-update** ecosystems + 7-day cooldown (org does alerts/updates, not version-bump config) | *conditional* — whichever ecosystems this repo's manifests actually use | uncomment those ecosystem(s) in `.github/dependabot.yml`; leave the rest commented out. `github-actions` is already active by default — every repo has workflows, so that one isn't part of the decision |
| **Scala SAST** — CodeQL can't parse Scala | *conditional* — Scala/JVM repos only | yes: keep `.github/workflows/semgrep.yml` enabled **+** add Scala Steward. no: **delete `.github/workflows/semgrep.yml`** |
| **Container / IaC scanning** — CodeQL doesn't scan images | *conditional* — Docker/compose repos only | yes: keep `.github/workflows/trivy.yml` enabled. no: **delete `.github/workflows/trivy.yml`** |
| **pnpm release-age gate** — pnpm's 24h default < 7-day policy | *conditional* — JS/pnpm repos only | yes: add `minimum-release-age=10080` to `.npmrc` (kebab-case — the confirmed, pnpm-normalized key) — **then un-ignore the file**: remove the `.npmrc` line from this repo's `.gitignore`, or negate it `!.npmrc` (never `!/.npmrc`, which still hides a nested workspace `.npmrc`). If this `.npmrc` also carries a registry auth token, interpolate it — `//registry.npmjs.org/:_authToken=${NPM_TOKEN}` — never a literal value. `sentinel` audits the gate by its *resolved* value (`pnpm config get minimumReleaseAge`), not by reading the file. no: don't create the file at all |

## Per repo (a few clicks)
- [ ] Install and wire pre-commit first: `pipx install pre-commit && pre-commit install`
  (gaps table, row 1). Every other box below results in a commit, and none of the local
  hooks (gitleaks, zizmor, actionlint, end-of-file-fixer) run until this is done —
  skipping it is how a repo carries a broken hook config with nothing ever having run it.
- [ ] **Branching policy** — decide, don't default: work directly on `main`, or require topic
  branches (`feat/`, `fix/`, `refactor/` + kebab-case) before merge? Decide from what this repo
  is — solo vs. multi-contributor, whether CI/deploys fire from `main`, how easily a commit
  reverts — not from habit. Add a Branching bullet under Conventions in `AGENTS.md` stating the
  answer in 1-2 sentences, so later sessions inherit the decision instead of guessing.
- [ ] **Dependabot ecosystems** — which, if any, does this repo's own manifests use (`sbt`, `npm`,
  `pip`, `gomod`, `cargo`, `docker`)? Uncomment those in `.github/dependabot.yml` and leave
  the rest commented out — a repo with no manifest in an ecosystem gets no entry for it.
- [ ] **Scala SAST** (`semgrep.yml`) — is this a Scala/JVM repo? If no, **delete
  `.github/workflows/semgrep.yml`** now, rather than leaving a disabled workflow for someone
  to wonder about later. If yes, leave it enabled and add Scala Steward.
- [ ] **Container/IaC scanning** (`trivy.yml`) — does this repo build a Docker image or ship
  compose/IaC files? If no, **delete `.github/workflows/trivy.yml`.** If yes, leave it enabled.
- [ ] **pnpm release-age gate** — is this a JS/pnpm repo? If no, do nothing — don't create
  `.npmrc` at all. If yes, add it per the gaps table row above, un-ignore it, and verify the
  resolved value.
- [ ] Set the repo **description** + **topics** (`fukuii`, `ethereum-classic`, …).
- [ ] Replace every `{{PLACEHOLDER}}` in `README.md`, `AGENTS.md`, `NOTICE`.
- [ ] Fill in `AGENTS.md` (the agent source of truth — `CLAUDE.md`/`copilot-instructions.md` point at it).
- [ ] Delete the "Template usage" section from `README.md` and the guidance comments in `AGENTS.md`.

> **Inherited from the org (`fukuii-project/.github`) — nothing to add per repo:** `SECURITY.md`,
> `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue templates, PR template. Only add a local copy to
> override the org default.
- [ ] `sentinel` repins any action SHAs / pre-commit `rev:`s per the supply-chain policy.

## Deliberately NOT doing (two-admin project)
No required reviews, no CODEOWNERS gate, no admin-bypass branch protection. Both owners are trusted
admins; CI runs and reports status but does **not** block merges. Work from forks by habit (free
fork-PR secret isolation) — unenforced.
