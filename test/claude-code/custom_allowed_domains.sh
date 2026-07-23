#!/bin/bash
set -e

source dev-container-features-test-lib

check "custom domain example.org is in the allowlist" bash -c "grep -qx 'example.org' /usr/local/etc/claude-code/allowed-domains.txt"
check "custom domain example.net is in the allowlist" bash -c "grep -qx 'example.net' /usr/local/etc/claude-code/allowed-domains.txt"
check "default required domain is still present alongside custom ones" bash -c "grep -qx 'api.anthropic.com' /usr/local/etc/claude-code/allowed-domains.txt"

reportResults
