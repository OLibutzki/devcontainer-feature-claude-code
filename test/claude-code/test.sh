#!/bin/bash
# Default-options scenario, run automatically by `devcontainer features test`.
set -e

source dev-container-features-test-lib

check "claude is on PATH" bash -c "command -v claude"
check "claude --version works" claude --version
check "/usr/local/bin/claude is a symlink into the remote user's install" bash -c "[ -L /usr/local/bin/claude ]"
check "running as non-root" bash -c "[ \"\$(id -u)\" != \"0\" ]"
check "CLAUDE_CONFIG_DIR is set to the persisted volume target" bash -c "[ \"\$CLAUDE_CONFIG_DIR\" = \"/home/.claude-code-config\" ]"
check "persisted config dir exists and is owned by the remote user" bash -c "[ -d /home/.claude-code-config ] && [ \"\$(stat -c %U /home/.claude-code-config)\" = \"\$(whoami)\" ]"

check "start script installed" bash -c "[ -x /usr/local/bin/claude-code-start.sh ]"
check "onboarding-init script installed" bash -c "[ -x /usr/local/bin/claude-code-onboarding-init.sh ]"
check "auto-onboarding defaults to true" bash -c "[ \"\$(cat /usr/local/etc/claude-code/auto-onboarding)\" = \"true\" ]"

check "firewall script installed" bash -c "[ -x /usr/local/bin/claude-code-init-firewall.sh ]"
check "default allowed-domains includes api.anthropic.com" bash -c "grep -qx 'api.anthropic.com' /usr/local/etc/claude-code/allowed-domains.txt"
check "default allowed-domains does not include github.com" bash -c "! grep -qx 'github.com' /usr/local/etc/claude-code/allowed-domains.txt"

check "onboarding-init is idempotent and sets hasCompletedOnboarding" bash -c "
  /usr/local/bin/claude-code-onboarding-init.sh &&
  /usr/local/bin/claude-code-onboarding-init.sh &&
  jq -e '.hasCompletedOnboarding == true' \"\$HOME/.claude.json\" &&
  jq -e '.hasCompletedOnboarding == true' \"\$CLAUDE_CONFIG_DIR/.claude.json\"
"

check "autoupdate-init script installed" bash -c "[ -x /usr/local/bin/claude-code-autoupdate-init.sh ]"
check "auto-update stays enabled by default (version is not pinned)" bash -c "[ \"\$(cat /usr/local/etc/claude-code/disable-autoupdater)\" = \"false\" ]"
check "no settings.json is shipped when version isn't pinned (and none touches permission mode)" bash -c "
  /usr/local/bin/claude-code-autoupdate-init.sh &&
  [ ! -e \"\$HOME/.claude/settings.json\" ] &&
  [ ! -e \"\$CLAUDE_CONFIG_DIR/settings.json\" ]
"

reportResults
