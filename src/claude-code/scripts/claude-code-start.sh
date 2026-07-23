#!/usr/bin/env bash
# postStartCommand entrypoint installed by this feature. Runs as the
# container's remote user on every container start (including after a
# rebuild). Does two things, neither of which touches Claude Code's
# permission mode:
#   1. (re-)apply the always-on egress firewall
#   2. mark onboarding complete, if enabled
set -euo pipefail

sudo /usr/local/bin/claude-code-init-firewall.sh

if [ "$(cat /usr/local/etc/claude-code/auto-onboarding 2>/dev/null || echo false)" = "true" ] \
  && [ -x /usr/local/bin/claude-code-onboarding-init.sh ]; then
  /usr/local/bin/claude-code-onboarding-init.sh
fi
