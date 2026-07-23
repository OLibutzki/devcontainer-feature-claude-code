# Claude Code Dev Container Feature

A [dev container feature](https://containers.dev/implementors/features/) that installs [Claude Code](https://claude.com/product/claude-code) and turns the container into a place where it's *safe to choose* to run `claude --dangerously-skip-permissions` for unattended work.

> **Experimental.** This is a 0.x release: expect breaking changes between versions until it reaches 1.0.

## Why not the official feature?

Anthropic publishes [`ghcr.io/anthropics/devcontainer-features/claude-code`](https://github.com/anthropics/devcontainer-features), but it's had no commits in over a year and an [open, unanswered question about whether it's deprecated](https://github.com/anthropics/devcontainer-features/issues/26). It also only runs a bare `npm install -g`, leaving three things unsolved for a sandboxed/unattended setup:

1. **Non-interactive login.** Setting `CLAUDE_CODE_OAUTH_TOKEN` alone doesn't skip the onboarding screen in a fresh container — you still need `hasCompletedOnboarding: true` in the Claude config ([claude-code#8938](https://github.com/anthropics/claude-code/issues/8938#issuecomment-3443723851)). This feature sets that automatically on every container start.
2. **Persisting a browser login across rebuilds, per project.** This feature mounts a named volume keyed by [`${devcontainerId}`](https://containers.dev/implementors/json_reference/#variables-in-devcontainerjson) — stable across rebuilds of the same dev container, different for different projects — with zero devcontainer.json edits required.
3. **Making `--dangerously-skip-permissions` reasonably safe.** Per the [official docs](https://code.claude.com/docs/en/devcontainer#run-without-permission-prompts), that requires a non-root `remoteUser` (Claude Code refuses to start in bypass mode as root) and benefits from restricted egress. This feature enforces the former and always installs an egress firewall for the latter — it's not optional, since it's the whole point of the sandbox.

**What this feature does *not* do:** choose a permission mode for you. It never sets `permissions.defaultMode`, never wraps `claude` to inject `--dangerously-skip-permissions`, and ships no `settings.json`. It only makes the environment safe enough that *you* can opt into that flag, per session, when you want unattended behavior. Plain `claude` behaves exactly as it would anywhere else.

## Usage

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  "features": {
    "ghcr.io/olibutzki/devcontainer-feature-claude-code/claude-code:0": {}
  }
}
```

That's it — no Node.js needed (Claude Code's [native installer](https://code.claude.com/docs/en/setup#install-claude-code) doesn't require it), and no `mounts`/`runArgs`/`postStartCommand` boilerplate to hand-write.

Rebuild the container, then either:

```bash
# interactive, with a human reviewing actions
claude

# unattended: no human at the keyboard, so use headless mode
claude -p --dangerously-skip-permissions "do the thing"
```

Use headless mode (`-p`) for unattended runs specifically: the interactive one-time bypass-permissions warning dialog [only appears in interactive sessions](https://code.claude.com/docs/en/permission-modes#skip-all-checks-with-bypasspermissions-mode) and would otherwise block a session with nobody there to press Enter. `-p` mode never shows it.

### Logging in

- **Token-based (recommended for unattended containers):** set `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token` on your host) as a [Codespaces secret](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces) or in `containerEnv`/your shell before `claude` starts. Onboarding is pre-completed automatically, so it works with no interaction.
- **Browser login:** just run `claude` and follow the prompt once. The session is stored on the volume this feature mounts, so it survives a rebuild of *this* devcontainer config — you won't need to log in again unless you delete the volume or change the workspace path.

## The firewall

This feature always installs a **default-deny outbound firewall for the whole container**, not just Claude Code's own traffic — it's not optional, since restricted egress is what makes `--dangerously-skip-permissions` a reasonable thing to opt into in the first place. The baked-in allowlist is exactly the ["Required for" domains](https://code.claude.com/docs/en/network-config#network-access-requirements) from Claude Code's own docs:

`api.anthropic.com`, `claude.ai`, `claude.com`, `platform.claude.com`, `mcp-proxy.anthropic.com`, `downloads.claude.ai`, `storage.googleapis.com`, `raw.githubusercontent.com`, `code.claude.com`

Nothing else — no GitHub, no npm/PyPI/other registries, no VS Code Server hosts — is allowed by default. **Your project will very likely need more than this.** Add what it needs via `allowedDomains`:

```json
{
  "features": {
    "ghcr.io/olibutzki/devcontainer-feature-claude-code/claude-code:0": {
      "allowedDomains": "github.com,api.github.com,objects.githubusercontent.com,registry.npmjs.org"
    }
  }
}
```

## Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `version` | string | `latest` | `latest`, `stable`, or an exact version (e.g. `2.1.89`), passed to the native installer. |
| `allowedDomains` | string | `""` | Comma-separated extra domains to allow through the always-on firewall. |
| `autoOnboarding` | boolean | `true` | Auto-complete onboarding on every container start so token/API-key logins don't hit the interactive setup screen. Purely cosmetic/UX — never touches permission modes. |

## How persistence works

The feature sets `CLAUDE_CONFIG_DIR=/home/.claude-code-config` and mounts a named volume, `claude-code-config-${devcontainerId}`, at that path — both declared inside the feature itself, so no changes to your `devcontainer.json` are needed. `${devcontainerId}` is stable across rebuilds of the same dev container config/workspace and differs between projects, which is exactly the "same project, new container" persistence this was built for.

## Local development / testing

With [Docker](https://www.docker.com/) and the [devcontainer CLI](https://github.com/devcontainers/cli) installed:

```bash
devcontainer features test -f claude-code -p .
```

or point a throwaway project's `devcontainer.json` at `src/claude-code` via a local path and `devcontainer up` / `devcontainer exec` it.

## License

[MIT](./LICENSE)
