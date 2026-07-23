#!/usr/bin/env bash
# Marks onboarding as complete in Claude Code's config file(s) so a
# CLAUDE_CODE_OAUTH_TOKEN / ANTHROPIC_API_KEY login doesn't hit the
# interactive theme/setup screen. Runs as the container's remote user on
# every container start (see claude-code-start.sh). Never touches
# permission-mode settings.
#
# Docs are ambiguous on whether CLAUDE_CONFIG_DIR relocates ~/.claude.json
# (which holds the OAuth session) or only the ~/.claude directory, so this
# patches both candidate locations defensively; jq makes each patch a safe,
# non-destructive merge.
set -euo pipefail

mark_onboarded() {
  local config_file="$1"
  local dir
  dir="$(dirname "$config_file")"
  mkdir -p "$dir"

  if [ ! -f "$config_file" ]; then
    echo '{}' >"$config_file"
  fi

  if ! jq -e '.hasCompletedOnboarding == true' "$config_file" >/dev/null 2>&1; then
    local tmp
    tmp="$(mktemp "${config_file}.XXXXXX")"
    jq '.hasCompletedOnboarding = true' "$config_file" >"$tmp"
    mv "$tmp" "$config_file"
  fi
}

mark_onboarded "$HOME/.claude.json"

if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ "${CLAUDE_CONFIG_DIR}" != "$HOME" ]; then
  mark_onboarded "${CLAUDE_CONFIG_DIR}/.claude.json"
fi
