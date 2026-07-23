# Claude Code Dev Container Feature

A [dev container feature](https://containers.dev/implementors/features/) that installs [Claude Code](https://claude.com/product/claude-code) and turns the container into a place where it's *safe to choose* to run `claude --dangerously-skip-permissions` for unattended work.

> **Experimental.** This is a 0.x release: expect breaking changes between versions until it reaches 1.0.

## Why not the official feature?

Anthropic's [`ghcr.io/anthropics/devcontainer-features/claude-code`](https://github.com/anthropics/devcontainer-features) has major unfixed bugs and no activity in over a year — see [issue #26](https://github.com/anthropics/devcontainer-features/issues/26).

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

Rebuild the container, then run Claude Code as usual — with a human reviewing actions:

```bash
claude
```

or, for unattended work, opt into bypassing permission checks:

```bash
claude --dangerously-skip-permissions
```

### Logging in

- **Token-based (recommended for unattended containers):** generate a token with `claude setup-token` on your host, then pass it through as `CLAUDE_CODE_OAUTH_TOKEN`. In Codespaces, add it as a [Codespaces secret](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces) and it's exposed automatically. Otherwise, add this to your `devcontainer.json` so it's read from your host shell rather than hardcoded:

  ```json
  "remoteEnv": {
    "CLAUDE_CODE_OAUTH_TOKEN": "${localEnv:CLAUDE_CODE_OAUTH_TOKEN}"
  }
  ```

  `remoteEnv` injects it into every terminal/exec session in the container (where `claude` runs) without baking it into the container's persisted config. Onboarding is pre-completed automatically, so it works with no interaction.
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

`autoOnboarding` exists because setting `CLAUDE_CODE_OAUTH_TOKEN` (or an API key) alone doesn't skip Claude Code's interactive onboarding screen in a fresh container — `hasCompletedOnboarding: true` needs to be set explicitly too, as noted in [claude-code#8938](https://github.com/anthropics/claude-code/issues/8938#issuecomment-3443723851). This feature sets that flag automatically so token-based logins actually work non-interactively.

`latest` and `stable` are Claude Code's own [release channels](https://code.claude.com/docs/en/setup#configure-release-channel), not something this feature defines: `latest` installs every release as soon as it ships, `stable` installs a version that's typically about a week old and skips releases with major regressions. On either channel, the native installer keeps [auto-updating in the background](https://code.claude.com/docs/en/setup#auto-updates) afterward, so the container tracks new releases on that channel over time — this is intentional, not something you need to work around.

An exact version (e.g. `2.1.89`) is different: this feature automatically sets [`DISABLE_UPDATES`](https://code.claude.com/docs/en/env-vars) in that case, blocking both background and manual (`claude update`) updates, so the pin actually sticks instead of silently drifting past the version you asked for. Switching `version` back to `latest`/`stable` on a later rebuild re-enables updates again.

## How persistence works

The feature sets `CLAUDE_CONFIG_DIR=/home/.claude-code-config` and mounts a named volume, `claude-code-config-${devcontainerId}`, at that path — both declared inside the feature itself, so no changes to your `devcontainer.json` are needed. `${devcontainerId}` is stable across rebuilds of the same dev container config/workspace and differs between projects, which is exactly the "same project, new container" persistence this was built for.

## Local development / testing

With [Docker](https://www.docker.com/) and the [devcontainer CLI](https://github.com/devcontainers/cli) installed:

```bash
devcontainer features test -f claude-code -p .
```

or point a throwaway project's `devcontainer.json` at `src/claude-code` via a local path and `devcontainer up` / `devcontainer exec` it.

The same test suite runs in GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) on every push and pull request; publishing to `ghcr.io` only happens after tests pass on `main`.

## License

[MIT](./LICENSE)
