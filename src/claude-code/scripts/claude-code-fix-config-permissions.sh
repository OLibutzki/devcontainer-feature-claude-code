#!/usr/bin/env bash
# Ensures the persisted CLAUDE_CONFIG_DIR volume is owned by the remote
# user. install.sh chowns this directory at build time so a fresh named
# volume inherits the right ownership when Docker copies the image's
# content into it on first mount -- but that copy-on-first-mount behavior
# isn't guaranteed by every container runtime configuration. It was
# observed to not happen on GitHub Actions' hosted runners, leaving the
# directory root-owned and unwritable by the non-root remote user, which
# broke claude-code-onboarding-init.sh and claude-code-autoupdate-init.sh
# on every run. Runs via sudo (root) from claude-code-start.sh, before
# anything else needs to write into that directory, so it works
# regardless of what ownership the runtime actually assigned.
set -euo pipefail

chown -R "${SUDO_USER:?claude-code-fix-config-permissions.sh must be run via sudo}" /home/.claude-code-config
