<!--
  README skeleton — the FRONT DOOR. Fill every {{PLACEHOLDER}}, add the logo, and delete these
  comments + the "Template usage" section at the bottom. Marketing-shaped on purpose: sell the
  *why*, then quick start. Deep build/test/architecture detail belongs in AGENTS.md and docs/,
  not here. Scale it: flagship/user-facing repos grow into full prose; utilitarian repos trim to
  logo + tagline + what-it-is + quick start. Keep it honest — describe what the repo actually is
  (state BETA/experimental up top if that's true).
-->

<div align="center">
  <img src="https://raw.githubusercontent.com/fukuii-project/fukuii-brand/HEAD/logo/fukuii-hex-logo.png" alt="{{REPO_NAME}}" width="280"/>
</div>

# {{REPO_NAME}}

### {{ONE-LINE TAGLINE — what it is, in a sentence}}

{{2–3 sentences: what this is and why it exists. Lead with the value, not the tech.}}

[![CI](https://github.com/fukuii-project/{{REPO_NAME}}/actions/workflows/ci.yml/badge.svg)](https://github.com/fukuii-project/{{REPO_NAME}}/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
<!-- add repo-specific badges: language/runtime · latest release · docker pulls · coverage -->

---

## Why {{REPO_NAME}}

- {{The sell — 2–4 bullets: the problem it solves, who needs it, what's distinctive.}}

## What it is

{{Honest, prose description of scope — what it does and, if useful, what it deliberately doesn't.}}

## Quick start

```bash
{{The one path to "it works" — docker run / install + run / clone + up.}}
```

## Configuration

Copy `.env.example` → `.env` and fill it in. **Never commit `.env`** — it's gitignored, and a
pre-commit hook + org secret scanning guard against leaks.

## Security

Report vulnerabilities privately via this repo's **Security → Report a vulnerability**
(org-wide [policy](https://github.com/fukuii-project/.github/blob/main/SECURITY.md)) — not public issues.

## Contributing

See the org-wide [Contributing guide](https://github.com/fukuii-project/.github/blob/main/CONTRIBUTING.md);
stack-specific build/test/style live in [`AGENTS.md`](AGENTS.md).

## License

[Apache-2.0](LICENSE). See [`NOTICE`](NOTICE) for attribution.

---

<sub>Part of the Fukuii project · [fukuii-project/fukuii](https://github.com/fukuii-project/fukuii)</sub>

<!-- ─────────────────────────────────────────────────────────────────────────
## Template usage (delete this whole section after creating a repo)

Created from **fukuii-project/fukuii-template**. Before your first real commit:

1. The shared Fukuii logo is wired by default (from `fukuii-brand`); swap it for a repo-specific mark only if this repo has one.
2. Fill every `{{PLACEHOLDER}}` here and in `AGENTS.md` and `NOTICE`.
3. Read [`.github/SETUP-CHECKLIST.md`](.github/SETUP-CHECKLIST.md) for the per-repo + stack steps.
4. Install pre-commit hooks: `pipx install pre-commit && pre-commit install`.
5. Delete this section and the guidance comment at the top.
──────────────────────────────────────────────────────────────────────────── -->
