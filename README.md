# GL.iNet Slate 7 (GL-BE3600) Tailscale Toggle Mode

This setup adds a **Tailscale** mode to the GL.iNet Slate7.  
When the toggle button is set to Tailscale, the screen shows `tailscale` and the router enables/disables Tailscale and configures masquerading so LAN traffic can go through a Tailscale exit node.

## Files

- `tailscale.sh`  
  Script called when the toggle button switches **on/off** Tailscale.
  - Calls the local JSON-RPC API (`tailscale get_config` / `set_config`).
  - Compares the current `enabled` value and only updates when needed.
  - Prints current and updated config JSON.
  - When enabling, waits (up to 30 seconds) for `tailscale0` to appear, then runs:
    - `uci set firewall.tailscale0.masq="1"`
    - `uci commit firewall`
    - `/etc/init.d/firewall reload`

## Installation

1. **Copy the script to the router**

   ```sh
   scp tailscale.sh root@<router-ip>:/etc/gl-switch.d/tailscale.sh
   ssh root@<router-ip> 'chmod +x /etc/gl-switch.d/tailscale.sh'
   ```

2. **Patch the screen display script (add `tailscale` mode)**

   Run on the router:

   ```sh
   FILE=/usr/bin/screen_disp_switch

   # Only patch if tailscale case is not present
   if ! grep -q '"tailscale")' "$FILE"; then
     sed -i '/"vpn")/i\
       "tailscale")\
           msg="tailscale"\
           ;;' "$FILE"
     echo "tailscale case added to $FILE."
   else
     echo "tailscale case already present in $FILE, nothing to do."
   fi
   ```

3. **Configure the toggle button in the web UI**

   - Open the Slate7 admin page.
   - Go to **System → Toggle Button Settings**.
   - Set the toggle **function** to **Tailscale**.

## Usage

- Flip the hardware toggle to the **Tailscale** position:
  - Screen shows `tailscale`.
  - `tailscale.sh on` runs, enabling Tailscale and masquerading.
- Flip away from Tailscale:
  - `tailscale.sh off` runs, disabling Tailscale (masquerade stays enabled once set).
