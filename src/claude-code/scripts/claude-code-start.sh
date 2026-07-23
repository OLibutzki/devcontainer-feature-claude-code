#!/usr/bin/env bash
# postStartCommand entrypoint installed by this feature. Runs as the
# container's remote user on every container start (including after a
# rebuild). Does four things, none of which touches Claude Code's
# permission mode:
#   1. make sure the persisted config volume is actually writable
#   2. (re-)apply the always-on egress firewall
#   3. mark onboarding complete, if enabled
#   4. sync the auto-updater's disabled/enabled state with whether
#      `version` is pinned to an exact release
set -euo pipefail

sudo /usr/local/bin/claude-code-fix-config-permissions.sh

sudo /usr/local/bin/claude-code-init-firewall.sh

if [ "$(cat /usr/local/etc/claude-code/auto-onboarding 2>/dev/null || echo false)" = "true" ] \
  && [ -x /usr/local/bin/claude-code-onboarding-init.sh ]; then
  /usr/local/bin/claude-code-onboarding-init.sh
fi

/usr/local/bin/claude-code-autoupdate-init.sh
