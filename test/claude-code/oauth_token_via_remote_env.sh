#!/bin/bash
# Exercises the remoteEnv + ${localEnv:...} pattern documented in the README
# for passing CLAUDE_CODE_OAUTH_TOKEN from the host into the container.
set -e

source dev-container-features-test-lib

check "CLAUDE_CODE_OAUTH_TOKEN set via remoteEnv reaches the exec/terminal environment" \
  bash -c "[ \"\$CLAUDE_CODE_OAUTH_TOKEN\" = \"test-oauth-token-value\" ]"

check "onboarding is still pre-completed alongside a token-based login" \
  bash -c "jq -e '.hasCompletedOnboarding == true' \"\$HOME/.claude.json\""

reportResults
