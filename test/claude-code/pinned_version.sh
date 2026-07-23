#!/bin/bash
set -e

source dev-container-features-test-lib

check "the pinned version is what actually got installed" bash -c "claude --version | grep -q '^2.1.218'"
check "disable-autoupdater flag is true when version is pinned" bash -c "[ \"\$(cat /usr/local/etc/claude-code/disable-autoupdater)\" = \"true\" ]"
check "DISABLE_UPDATES is set in the persisted settings.json" bash -c "jq -e '.env.DISABLE_UPDATES == \"1\"' \"\$CLAUDE_CONFIG_DIR/settings.json\""
check "settings.json still doesn't touch permission mode" bash -c "[ \"\$(jq -r 'has(\"permissions\")' \"\$CLAUDE_CONFIG_DIR/settings.json\")\" = \"false\" ]"

reportResults
