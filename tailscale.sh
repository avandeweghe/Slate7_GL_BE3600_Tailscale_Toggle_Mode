#!/bin/sh
# /etc/gl-switch. d/tailscale.sh

# Set to 1 to enable masquerading on tailscale0 when Tailscale is enabled,
# or 0 to skip all masquerade changes.
MASQ_ENABLED=0

# Helper: enable masquerading on tailscale0 zone in OpenWrt firewall
enable_masquerade() {
  # Wait up to 30 seconds for tailscale0 interface to appear
  echo "Waiting for tailscale0 interface (timeout 30s)..."
  i=0
  while [ "$i" -lt 30 ]; do
    if ip link show tailscale0 >/dev/null 2>&1; then
      echo "tailscale0 interface detected. Enabling masquerading..."
      break
    fi
    i=`expr "$i" + 1`
    sleep 1
  done

  if [ "$i" -ge 30 ]; then
    echo "Warning: tailscale0 interface not found within 30 seconds. Skipping masquerade enable."
    return 1
  fi

  uci set firewall.tailscale0.masq="1" || {
    echo "Warning: failed to set firewall.tailscale0.masq=1"
    return 1
  }
  uci commit firewall || {
    echo "Warning: failed to commit firewall config"
    return 1
  }
  /etc/init.d/firewall reload || {
    echo "Warning: failed to reload firewall"
    return 1
  }

  echo "Masquerading on tailscale0 enabled"
}

action=$1

if [ "$action" = "on" ]; then
  enabled=true
elif [ "$action" = "off" ]; then
  enabled=false
else
  echo "Usage: $0 [on|off]"
  exit 1
fi

# Define JSON-RPC payload for get_config
get_config_payload='{"jsonrpc":"2.0","method":"call","params":["","tailscale","get_config"],"id":1}'

# Get current config
echo "Fetching current config..."
response=$(curl -H 'glinet: 1' -s -k http://127.0.0.1/rpc \
  -d "$get_config_payload")

# Extract only the value of "result" (a JSON object) using jsonfilter
config=$(echo "$response" | jsonfilter -e '@.result')

if [ -z "$config" ] || [ "$config" = "null" ]; then
  echo "Error: Failed to fetch config"
  echo "Full response was: $response"
  exit 1
fi

echo "Current config: $config"

# Check current enabled value using jsonfilter (expects true/false)
current_enabled=$(echo "$config" | jsonfilter -e '@.enabled')

if [ "$current_enabled" = "$enabled" ]; then
  echo "No change needed: enabled is already $current_enabled"
  # Still ensure masquerading is enabled when tailscale is enabled
  if [ "$enabled" = true ] && [ "$MASQ_ENABLED" = "1" ]; then
    enable_masquerade
  fi
  exit 0
fi

# Replace the enabled value in the config (true/false) using sed
# Then remove lan_ip from the updated config before sending it
updated_config=$(echo "$config" \
  | sed "s/\"enabled\":[^,}]*/\"enabled\":$enabled/" \
  | sed 's/"lan_ip" *:[^,}]*, *//; s/, *"lan_ip" *:[^,}]*//')
echo "Updated config (lan_ip removed): $updated_config"
echo "Setting config with enabled=$enabled..."

# Build JSON-RPC payload for set_config dynamically
set_config_payload=$(printf '{"jsonrpc":"2.0","method":"call","params":["","tailscale","set_config",%s],"id":1}' "$updated_config")

# Send updated config back via set_config
curl -H 'glinet: 1' -s -k http://127.0.0.1/rpc \
  -d "$set_config_payload"

echo ""
echo "Config updated successfully"

# Enable masquerading when tailscale is enabled
if [ "$enabled" = true ] && [ "$MASQ_ENABLED" = "1" ]; then
  enable_masquerade
fi