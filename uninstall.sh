#!/bin/bash
# Removes the Omarchy VPN bar plugin. Does not touch your saved server
# configs (~/.config/omarchy/vpn, /etc/amnezia/amneziawg).
set -euo pipefail

rm -f "$HOME/.config/omarchy/bar/modules/vpn.qml"
sudo rm -f /usr/local/bin/omarchy-vpn-ctl /usr/local/bin/omarchy-vpn-servers /usr/local/bin/omarchy-vpn-add-server
sudo rm -f /etc/sudoers.d/omarchy-vpn

echo "Плагин удалён. Не забудь убрать запись {\"id\": \"vpn\"} из ~/.config/omarchy/shell.json и перезапустить бар (omarchy-restart-shell)."
