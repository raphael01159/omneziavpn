#!/bin/bash
# Installs the privileged backend for the OmneziaVpn Omarchy plugin
# (AmneziaWG/WireGuard control scripts + a scoped sudoers rule). The bar
# widget itself is installed separately via `omarchy plugin add`/`enable`
# (see README) -- this script only sets up what that command never touches:
# system binaries and sudo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Проверка зависимостей"
missing=()
for bin in awg awg-quick gum jq python3 sudo resolvconf; do
  command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "Не найдены: ${missing[*]}"
  echo "Установи их, например: yay -S --needed amneziawg-tools amneziawg-dkms systemd-resolvconf gum jq python"
  exit 1
fi
if ! modinfo amneziawg >/dev/null 2>&1 && ! command -v amneziawg-go >/dev/null 2>&1; then
  echo "Нет datapath AmneziaWG: модуль ядра amneziawg или userspace amneziawg-go"
  echo "Установи, например: yay -S --needed amneziawg-dkms"
  echo "  (или userspace: yay -S --needed amneziawg-go)"
  exit 1
fi
command -v notify-send >/dev/null 2>&1 || echo "==> notify-send не найден — плагин будет работать, но без уведомлений (пакет libnotify)"

echo "==> Копирую управляющие скрипты в /usr/local/bin (нужен sudo)"
sudo install -Dm755 "$SCRIPT_DIR/bin/omarchy-vpn-ctl" /usr/local/bin/omarchy-vpn-ctl
sudo install -Dm755 "$SCRIPT_DIR/bin/omarchy-vpn-servers" /usr/local/bin/omarchy-vpn-servers
sudo install -Dm755 "$SCRIPT_DIR/bin/omarchy-vpn-add-server" /usr/local/bin/omarchy-vpn-add-server
sudo install -Dm755 "$SCRIPT_DIR/bin/omarchy-vpn-rename-server" /usr/local/bin/omarchy-vpn-rename-server

# shellcheck source=lib/sudoers.sh
source "$SCRIPT_DIR/lib/sudoers.sh"
sudoers_user=$(omneziavpn_sudoers_user)
echo "==> Ставлю sudoers-правило для $sudoers_user (без пароля только omarchy-vpn-ctl)"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
omneziavpn_render_sudoers "$sudoers_user" > "$tmp"
sudo visudo -c -f "$tmp"
sudo install -Dm440 "$tmp" /etc/sudoers.d/omarchy-vpn
sudo visudo -c -f /etc/sudoers.d/omarchy-vpn

echo "==> Готово. Если виджет ещё не включён в баре:"
echo "    omarchy plugin add $(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo '<URL репозитория>') --enable"
echo "    (или omarchy plugin enable raphael01159.omneziavpn, если уже склонирован)"
