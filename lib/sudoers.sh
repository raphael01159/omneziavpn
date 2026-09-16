#!/bin/bash
# Renders the scoped sudoers rule for whoever is installing the backend.
# `bash lib/sudoers.sh` prints the rule; install.sh sources the functions.
set -euo pipefail

omneziavpn_sudoers_user() {
  local sudoers_user="${SUDO_USER:-${USER:-}}"
  if [ -z "$sudoers_user" ] || [ "$sudoers_user" = "root" ]; then
    echo "запусти install.sh от своего пользователя, не от root (сейчас: '${sudoers_user:-}')" >&2
    return 1
  fi
  case "$sudoers_user" in
    *[!a-zA-Z0-9_.-]*)
      echo "некорректное имя пользователя для sudoers: $sudoers_user" >&2
      return 1
      ;;
  esac
  printf '%s' "$sudoers_user"
}

omneziavpn_render_sudoers() {
  local sudoers_user="${1:-}"
  if [ -z "$sudoers_user" ]; then
    echo "omneziavpn_render_sudoers: нужен пользователь" >&2
    return 1
  fi
  printf '%s ALL=(root) NOPASSWD: /usr/local/bin/omarchy-vpn-ctl\n' "$sudoers_user"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  omneziavpn_render_sudoers "$(omneziavpn_sudoers_user)"
fi
