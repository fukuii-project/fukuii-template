# New-repo setup checklist

## Security: what's automatic vs what this repo adds
The **org Security Configuration** (`fukuii-project-org-config-1`) already **enforces** the common
baseline on every repo — **secret scanning + push protection, CodeQL, Dependabot alerts + security
updates** — inherited, nothing to enable per repo.

This repo fills the **gaps the org baseline can't reach**, by stack:

| Gap the org config misses | Applies to | Action |
|---|---|---|
| Local pre-commit edge (secrets **and** Actions hardening — org scans server-side + doesn't audit workflows) | all | `pipx install pre-commit && pre-commit install` (gitleaks + zizmor + actionlint) |
| Dependabot **version-update** ecosystems + 7-day cooldown (org does alerts/updates, not version-bump config) | all | uncomment your ecosystem in `.github/dependabot.yml` |
| **Scala SAST** — CodeQL can't parse Scala | Scala/JVM repos | enable `.github/workflows/semgrep.yml` **+** add Scala Steward |
| **Container / IaC scanning** — CodeQL doesn't scan images | Docker/compose repos | enable `.github/workflows/trivy.yml` |
| **pnpm release-age gate** — pnpm's 24h default < 7-day policy | JS/pnpm repos | add `.npmrc` `minimum-release-age=10080` (verify the exact key via sentinel) |

## Per repo (a few clicks)
- [ ] Install and wire pre-commit first: `pipx install pre-commit && pre-commit install`
  (gaps table, row 1). Every other box below results in a commit, and none of the local
  hooks (gitleaks, zizmor, actionlint, end-of-file-fixer) run until this is done —
  skipping it is how a repo carries a broken hook config with nothing ever having run it.
- [ ] Set the repo **description** + **topics** (`fukuii`, `ethereum-classic`, …).
- [ ] Replace every `{{PLACEHOLDER}}` in `README.md`, `AGENTS.md`, `NOTICE`.
- [ ] Fill in `AGENTS.md` (the agent source of truth — `CLAUDE.md`/`copilot-instructions.md` point at it).
- [ ] Delete the "Template usage" section from `README.md` and the guidance comments in `AGENTS.md`.

> **Inherited from the org (`fukuii-project/.github`) — nothing to add per repo:** `SECURITY.md`,
> `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, issue templates, PR template. Only add a local copy to
> override the org default.
- [ ] Uncomment this repo's ecosystem(s) in `.github/dependabot.yml`.
- [ ] Enable the stack gap-fillers above that apply (delete the ones that don't).
- [ ] `sentinel` repins any action SHAs / pre-commit `rev:`s per the supply-chain policy.

## Deliberately NOT doing (two-admin project)
No required reviews, no CODEOWNERS gate, no admin-bypass branch protection. Both owners are trusted
admins; CI runs and reports status but does **not** block merges. Work from forks by habit (free
fork-PR secret isolation) — unenforced.
