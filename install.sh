#!/bin/bash
# Installs the Omarchy VPN bar plugin (AmneziaWG/WireGuard toggle + server list).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Проверка зависимостей"
missing=()
for bin in awg awg-quick gum jq python3 sudo; do
  command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "Не найдены: ${missing[*]}"
  echo "Установи их, например: sudo pacman -S --needed amneziawg-tools gum jq python"
  exit 1
fi

echo "==> Копирую bar-модуль"
install -Dm644 "$SCRIPT_DIR/bar/modules/vpn.qml" "$HOME/.config/omarchy/bar/modules/vpn.qml"

echo "==> Копирую управляющие скрипты в /usr/local/bin (нужен sudo)"
sudo install -Dm755 "$SCRIPT_DIR/bin/omarchy-vpn-ctl" /usr/local/bin/omarchy-vpn-ctl
sudo install -Dm755 "$SCRIPT_DIR/bin/omarchy-vpn-servers" /usr/local/bin/omarchy-vpn-servers
sudo install -Dm755 "$SCRIPT_DIR/bin/omarchy-vpn-add-server" /usr/local/bin/omarchy-vpn-add-server

echo "==> Ставлю sudoers-правило (разрешает только omarchy-vpn-ctl без пароля)"
sudo install -Dm440 "$SCRIPT_DIR/sudoers/omarchy-vpn" /etc/sudoers.d/omarchy-vpn
sudo visudo -c -f /etc/sudoers.d/omarchy-vpn

CONFIG_JSON="$HOME/.config/omarchy/shell.json"
if [ -f "$CONFIG_JSON" ] && command -v jq >/dev/null 2>&1; then
  if jq -e '.. | objects | select(.id? == "vpn")' "$CONFIG_JSON" >/dev/null 2>&1; then
    echo "==> В shell.json уже есть модуль vpn, пропускаю"
  else
    echo "==> Модуль 'vpn' не найден в shell.json."
    echo "    Добавь вручную в массив modules бара объект: {\"id\": \"vpn\", \"type\": \"qml\"}"
  fi
else
  echo "==> Не нашёл ~/.config/omarchy/shell.json — добавь модуль вручную:"
  echo '    {"id": "vpn", "type": "qml"}'
fi

echo "==> Перезапускаю бар"
command -v omarchy-restart-shell >/dev/null 2>&1 && omarchy-restart-shell || echo "Перезапусти Omarchy shell вручную"

echo "==> Готово. Конфиг сервера добавляется через иконку VPN в баре -> '+ Добавить сервер'."
