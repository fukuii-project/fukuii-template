<!--
  AGENTS.md — the single source of truth for AI agents in this repo.
  Read natively by BOTH Claude Code and GitHub Copilot. `CLAUDE.md` and
  `.github/copilot-instructions.md` are thin pointers to THIS file — edit here, not there.
  After "Use this template": fill every {{PLACEHOLDER}} and delete the guidance comments.
-->

# {{REPO_NAME}} — agent guide

{{ONE_LINE_DESCRIPTION}} Part of the [Fukuii project](https://github.com/fukuii-project).

## Setup & commands
```bash
{{INSTALL}}   # e.g. pnpm install · sbt update · go mod download
{{BUILD}}     # build
{{TEST}}      # run tests
{{LINT}}      # format + lint
```

## Architecture
{{Short map — the main dirs/modules and what they do; where the entry point is.}}

## Conventions
- **Commits:** Conventional Commits (`type(scope): summary`) — see the org [Contributing guide](https://github.com/fukuii-project/.github/blob/main/CONTRIBUTING.md).
- **Style:** {{formatter/linter — scalafmt · prettier · gofmt · ruff}}.
- {{Any repo-specific rule an agent must follow.}}

## Testing
{{How to run the right tests for a change; what must pass before a PR.}}

## Security (agents: read this)
- Repos are **public.** Never write a secret into a file, a commit, or a log.
- Secrets reach code only via env vars / GitHub Actions secrets — **never literals.**
- `.env` and key material are gitignored *and* denied to agents in `.claude/settings.json`.

## Agents & MCP
- Shared agents/skills come from the org plugin (when installed); repo-specific ones live in `.claude/`.
- MCP servers, if any, go in `.mcp.json` using **`${VAR}` expansion only** — never a literal token, and
  only servers safe for a public repo (no broad shell/filesystem/exfil capability). Example:
  ```json
  { "mcpServers": { "github": { "command": "…", "env": { "GITHUB_TOKEN": "${GITHUB_TOKEN}" } } } }
  ```

## Gotchas
{{The highest-value section: non-obvious things that trip agents up. Fill from experience.}}
