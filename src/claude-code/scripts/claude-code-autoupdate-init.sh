#!/usr/bin/env bash
# Disables Claude Code's updates entirely when the `version` option was
# pinned to an exact release at install time, so the pin actually sticks.
# Sets DISABLE_UPDATES rather than DISABLE_AUTOUPDATER: the latter only
# stops the background update check, but `claude update`/`claude install`
# would still work manually and could move a deliberately pinned container
# past the version this option asked for. `version: latest`/`stable` are
# left alone (and any stale disable from a previous pinned build is cleaned
# up) since those are meant to track that release channel automatically.
# Runs as the container's remote user on every container start (see
# claude-code-start.sh). Never touches permission-mode settings.
#
# Same defensive-dual-path approach as claude-code-onboarding-init.sh:
# CLAUDE_CONFIG_DIR unambiguously relocates ~/.claude/settings.json per
# Claude Code's docs, but both candidate paths are patched anyway for
# cheap extra safety.
set -euo pipefail

PINNED="$(cat /usr/local/etc/claude-code/disable-autoupdater 2>/dev/null || echo false)"

sync_settings() {
  local settings_file="$1"
  local dir
  dir="$(dirname "$settings_file")"

  if [ "$PINNED" = "true" ]; then
    mkdir -p "$dir"
    [ -f "$settings_file" ] || echo '{}' >"$settings_file"

    if ! jq -e '.env.DISABLE_UPDATES == "1"' "$settings_file" >/dev/null 2>&1; then
      local tmp
      tmp="$(mktemp "${settings_file}.XXXXXX")"
      jq '.env.DISABLE_UPDATES = "1"' "$settings_file" >"$tmp"
      mv "$tmp" "$settings_file"
    fi
  elif [ -f "$settings_file" ]; then
    # No-op when the key was never set; clears a stale disable left behind
    # by a previous pinned version after the option changes back to
    # latest/stable on a rebuild that reuses an existing persisted volume.
    local tmp
    tmp="$(mktemp "${settings_file}.XXXXXX")"
    jq 'del(.env.DISABLE_UPDATES)' "$settings_file" >"$tmp"
    mv "$tmp" "$settings_file"
  fi
}

sync_settings "$HOME/.claude/settings.json"

if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ "${CLAUDE_CONFIG_DIR}" != "$HOME" ]; then
  sync_settings "${CLAUDE_CONFIG_DIR}/settings.json"
fi
