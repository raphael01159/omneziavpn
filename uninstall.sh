#!/bin/bash
# Removes the Omarchy VPN bar plugin. Does not touch your saved server
# configs (~/.config/omarchy/vpn, /etc/amnezia/amneziawg).
set -euo pipefail

rm -f "$HOME/.config/omarchy/bar/modules/vpn.qml"
sudo rm -f /usr/local/bin/omarchy-vpn-ctl /usr/local/bin/omarchy-vpn-servers /usr/local/bin/omarchy-vpn-add-server /usr/local/bin/omarchy-vpn-rename-server
sudo rm -f /etc/sudoers.d/omarchy-vpn

CONFIG_JSON="$HOME/.config/omarchy/shell.json"
if [ -f "$CONFIG_JSON" ] && command -v jq >/dev/null 2>&1; then
  tmp=$(mktemp)
  jq '(.bar.layout // {}) |= with_entries(.value |= map(select(.id != "vpn")))' "$CONFIG_JSON" > "$tmp" \
    && mv "$tmp" "$CONFIG_JSON" \
    || rm -f "$tmp"
fi

command -v omarchy-restart-shell >/dev/null 2>&1 && omarchy-restart-shell

echo "Плагин удалён. Сохранённые конфиги серверов (~/.config/omarchy/vpn, /etc/amnezia/amneziawg) не тронуты — удаляй вручную при необходимости."
