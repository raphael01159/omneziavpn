#!/bin/bash
# Removes the OmneziaVpn privileged backend (control scripts + sudoers rule).
# Does not touch saved server configs (~/.config/omarchy/vpn,
# /etc/amnezia/amneziawg) or the bar widget itself -- remove that with:
#   omarchy plugin remove raphael01159.omneziavpn
set -euo pipefail

sudo rm -f /usr/local/bin/omarchy-vpn-ctl /usr/local/bin/omarchy-vpn-servers /usr/local/bin/omarchy-vpn-add-server /usr/local/bin/omarchy-vpn-rename-server
sudo rm -f /etc/sudoers.d/omarchy-vpn

echo "Бэкенд удалён. Чтобы убрать сам виджет из бара: omarchy plugin remove raphael01159.omneziavpn"
echo "Сохранённые конфиги серверов (~/.config/omarchy/vpn, /etc/amnezia/amneziawg) не тронуты — удаляй вручную при необходимости."
