#!/bin/bash
# Renders the scoped sudoers rule for whoever is installing the backend.
# `bash lib/sudoers.sh` prints the rule; install.sh sources the functions.
set -euo pipefail

omneziavpn_sudoers_user() {
  local u="${SUDO_USER:-${USER:-}}"
  if [ -z "$u" ] || [ "$u" = "root" ]; then
    echo "запусти install.sh от своего пользователя, не от root (сейчас: '${u:-}')" >&2
    return 1
  fi
  case "$u" in
    *[!a-zA-Z0-9_.-]*)
      echo "некорректное имя пользователя для sudoers: $u" >&2
      return 1
      ;;
  esac
  printf '%s' "$u"
}

omneziavpn_render_sudoers() {
  local u
  u=$(omneziavpn_sudoers_user) || return 1
  printf '%s ALL=(root) NOPASSWD: /usr/local/bin/omarchy-vpn-ctl\n' "$u"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  omneziavpn_render_sudoers
fi
