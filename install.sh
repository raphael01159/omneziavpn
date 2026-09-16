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
sudo install -Dm755 "$SCRIPT_DIR/bin/omarchy-vpn-rename-server" /usr/local/bin/omarchy-vpn-rename-server

echo "==> Ставлю sudoers-правило (разрешает только omarchy-vpn-ctl без пароля)"
sudo install -Dm440 "$SCRIPT_DIR/sudoers/omarchy-vpn" /etc/sudoers.d/omarchy-vpn
sudo visudo -c -f /etc/sudoers.d/omarchy-vpn

CONFIG_JSON="$HOME/.config/omarchy/shell.json"
MODULE_ENTRY='{"id": "vpn", "type": "qml"}'

if [ ! -f "$CONFIG_JSON" ]; then
  echo "==> Создаю $CONFIG_JSON"
  mkdir -p "$(dirname "$CONFIG_JSON")"
  echo '{"version": 1, "bar": {"layout": {"right": []}}}' > "$CONFIG_JSON"
fi

if jq -e '.. | objects | select(.id? == "vpn")' "$CONFIG_JSON" >/dev/null 2>&1; then
  echo "==> В shell.json уже есть модуль vpn, пропускаю"
else
  echo "==> Добавляю модуль vpn в правую секцию бара (shell.json)"
  tmp=$(mktemp)
  jq '.bar.layout.right = ((.bar.layout.right // []) + ['"$MODULE_ENTRY"'])' "$CONFIG_JSON" > "$tmp" \
    && mv "$tmp" "$CONFIG_JSON" \
    || { rm -f "$tmp"; echo "Не получилось отредактировать shell.json, добавь вручную: $MODULE_ENTRY"; }
fi

echo "==> Опционально: автоподключение к последнему серверу при старте бара —"
echo '    добавь "settings": {"autoconnect": true} к модулю vpn в shell.json'

echo "==> Перезапускаю бар"
command -v omarchy-restart-shell >/dev/null 2>&1 && omarchy-restart-shell || echo "Перезапусти Omarchy shell вручную"

echo "==> Готово. Конфиг сервера добавляется через иконку VPN в баре -> '+ Добавить сервер'."
