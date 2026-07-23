#!/usr/bin/env bash
# Default-deny egress firewall: only DNS, loopback, the host's own subnet,
# and the domains listed in /usr/local/etc/claude-code/allowed-domains.txt
# (one per line, built at feature-install time from the documented Claude
# Code network requirements plus the allowedDomains option) are reachable.
#
# Adapted from the structure of anthropics/claude-code's
# .devcontainer/init-firewall.sh, simplified to plain DNS-resolved domain
# allowlisting (no GitHub CIDR-range handling: that's a general dev-workflow
# convenience, not something Claude Code itself requires, so it's left to
# the allowedDomains option instead of being baked into the default).
#
# Runs via sudo (see the NOPASSWD sudoers entry install.sh writes) from
# claude-code-start.sh on every container start.
set -euo pipefail
IFS=$'\n\t'

DOMAINS_FILE="/usr/local/etc/claude-code/allowed-domains.txt"

if [ ! -r "$DOMAINS_FILE" ]; then
  echo "claude-code-init-firewall: $DOMAINS_FILE not found, nothing to do" >&2
  exit 1
fi

# 1. Extract Docker's own DNS NAT rules before flushing, so they can be restored.
DOCKER_DNS_RULES=$(iptables-save -t nat 2>/dev/null | grep "127\.0\.0\.11" || true)

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy claude-code-allowed 2>/dev/null || true

if [ -n "$DOCKER_DNS_RULES" ]; then
  echo "Restoring Docker DNS rules..."
  iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
  iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
  echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
fi

# Allow DNS, loopback, and established connections before anything else.
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create claude-code-allowed hash:net

echo "Resolving allowed domains..."
while IFS= read -r domain; do
  [ -z "$domain" ] && continue
  case "$domain" in \#*) continue ;; esac

  ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')
  if [ -z "$ips" ]; then
    echo "WARNING: could not resolve $domain, skipping" >&2
    continue
  fi

  while IFS= read -r ip; do
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      echo "WARNING: unexpected DNS answer for $domain: $ip, skipping" >&2
      continue
    fi
    echo "Allowing $domain -> $ip"
    ipset add claude-code-allowed "$ip" 2>/dev/null || true
  done <<<"$ips"
done <"$DOMAINS_FILE"

# Allow the host's own subnet so the dev container tooling (editor <-> container) keeps working.
HOST_IP=$(ip route | awk '/^default/ {print $3; exit}')
if [ -n "$HOST_IP" ]; then
  HOST_NETWORK=$(echo "$HOST_IP" | sed -E 's/\.[0-9]+$/.0\/24/')
  echo "Host network detected as: $HOST_NETWORK"
  iptables -A INPUT -s "$HOST_NETWORK" -j ACCEPT
  iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT
fi

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A OUTPUT -m set --match-set claude-code-allowed dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configuration complete"
echo "Verifying firewall rules..."
if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
  echo "ERROR: firewall verification failed - was able to reach https://example.com" >&2
  exit 1
fi
echo "Verified: https://example.com is blocked, as expected"

if ! curl --connect-timeout 5 https://api.anthropic.com >/dev/null 2>&1; then
  echo "ERROR: firewall verification failed - unable to reach https://api.anthropic.com" >&2
  exit 1
fi
echo "Verified: https://api.anthropic.com is reachable, as expected"
