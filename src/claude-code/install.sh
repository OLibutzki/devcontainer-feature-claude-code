#!/usr/bin/env bash
# Installs Claude Code via the official native installer
# (https://claude.ai/install.sh) and wires up the runtime scripts that make
# --dangerously-skip-permissions a safe *option* to opt into inside this
# container: a persisted config volume, an onboarding-flag fixup, and an
# always-on default-deny egress firewall. Runs as root during image build.
set -euo pipefail

VERSION="${VERSION:-latest}"
ALLOWEDDOMAINS="${ALLOWEDDOMAINS:-}"
AUTOONBOARDING="${AUTOONBOARDING:-true}"

: "${_REMOTE_USER:?claude-code feature must be installed by a devcontainer CLI that sets _REMOTE_USER}"
: "${_REMOTE_USER_HOME:?claude-code feature must be installed by a devcontainer CLI that sets _REMOTE_USER_HOME}"

if [ "$_REMOTE_USER" = "root" ]; then
  echo "claude-code: refusing to install for remoteUser=root -- Claude Code itself refuses to run" >&2
  echo "with --dangerously-skip-permissions as root, so this feature requires a non-root remoteUser" >&2
  echo "in devcontainer.json (this is what makes the sandbox meaningful in the first place)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/usr/local/etc/claude-code"
CONTAINER_CLAUDE_CONFIG_DIR="/home/.claude-code-config"

echo "== claude-code: installing base dependencies =="
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends \
    curl ca-certificates jq sudo \
    iptables ipset iproute2 dnsutils
  rm -rf /var/lib/apt/lists/*
else
  echo "claude-code: apt-get not found; this feature only supports Debian/Ubuntu-based base images." >&2
  echo "Install curl, ca-certificates, jq, iptables, ipset, iproute2, and dnsutils yourself," >&2
  echo "or use an apt-based image." >&2
  command -v curl >/dev/null 2>&1 || exit 1
  command -v jq >/dev/null 2>&1 || exit 1
fi

echo "== claude-code: installing Claude Code (native installer) as $_REMOTE_USER =="
INSTALL_CMD="curl -fsSL https://claude.ai/install.sh | bash"
# "latest"/"stable" are Claude Code's own release channels: leave updates
# alone so the container keeps tracking that channel. Anything else is an
# exact pin, so updates (background AND manual) get disabled (see
# claude-code-autoupdate-init.sh) -- otherwise the pin wouldn't stick.
PINNED="true"
case "$VERSION" in
latest | "")
  PINNED="false"
  ;;
stable)
  INSTALL_CMD="$INSTALL_CMD -s stable"
  PINNED="false"
  ;;
*)
  INSTALL_CMD="$INSTALL_CMD -s $VERSION"
  ;;
esac

su - "$_REMOTE_USER" -c "$INSTALL_CMD"

CLAUDE_BIN="$_REMOTE_USER_HOME/.local/bin/claude"
if [ ! -e "$CLAUDE_BIN" ]; then
  echo "claude-code: expected native installer to create $CLAUDE_BIN, but it's missing" >&2
  exit 1
fi
ln -sf "$CLAUDE_BIN" /usr/local/bin/claude

echo "== claude-code: preparing persisted config volume target =="
mkdir -p "$CONTAINER_CLAUDE_CONFIG_DIR"
chown -R "$_REMOTE_USER" "$CONTAINER_CLAUDE_CONFIG_DIR"
chmod 700 "$CONTAINER_CLAUDE_CONFIG_DIR"

echo "== claude-code: installing runtime scripts =="
install -m 0755 "$SCRIPT_DIR/scripts/claude-code-start.sh" /usr/local/bin/claude-code-start.sh
install -m 0755 "$SCRIPT_DIR/scripts/claude-code-fix-config-permissions.sh" /usr/local/bin/claude-code-fix-config-permissions.sh
install -m 0755 "$SCRIPT_DIR/scripts/claude-code-onboarding-init.sh" /usr/local/bin/claude-code-onboarding-init.sh
install -m 0755 "$SCRIPT_DIR/scripts/claude-code-autoupdate-init.sh" /usr/local/bin/claude-code-autoupdate-init.sh

mkdir -p "$CONFIG_DIR"
echo "$AUTOONBOARDING" >"$CONFIG_DIR/auto-onboarding"
echo "$PINNED" >"$CONFIG_DIR/disable-autoupdater"

echo "== claude-code: installing firewall =="
install -m 0755 "$SCRIPT_DIR/scripts/claude-code-init-firewall.sh" /usr/local/bin/claude-code-init-firewall.sh

{
  # Required domains per https://code.claude.com/docs/en/network-config#network-access-requirements
  echo "api.anthropic.com"
  echo "claude.ai"
  echo "claude.com"
  echo "platform.claude.com"
  echo "mcp-proxy.anthropic.com"
  echo "downloads.claude.ai"
  echo "storage.googleapis.com"
  echo "raw.githubusercontent.com"
  echo "code.claude.com"
  if [ -n "$ALLOWEDDOMAINS" ]; then
    echo "$ALLOWEDDOMAINS" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sed '/^$/d'
  fi
} >"$CONFIG_DIR/allowed-domains.txt"

echo "$_REMOTE_USER ALL=(root) NOPASSWD: /usr/local/bin/claude-code-init-firewall.sh, /usr/local/bin/claude-code-fix-config-permissions.sh" >/etc/sudoers.d/claude-code-firewall
chmod 0440 /etc/sudoers.d/claude-code-firewall

echo "== claude-code: install.sh complete =="
