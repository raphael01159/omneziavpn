#!/usr/bin/env python3
"""Regression tests for the OmneziaVpn sudoers rule.

The bar widget and add-server flow call `sudo -n /usr/local/bin/omarchy-vpn-ctl`.
install.sh must write a NOPASSWD rule for whoever is installing — the default
Omarchy login `omarchy` or any other username, with the same rule shape.
"""
import os
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RENDER = ROOT / "lib" / "sudoers.sh"
CTL = "/usr/local/bin/omarchy-vpn-ctl"


def render(**overrides):
    merged = os.environ.copy()
    for key, value in overrides.items():
        if value is None:
            merged.pop(key, None)
        else:
            merged[key] = value
    return subprocess.run(
        ["bash", str(RENDER)],
        cwd=ROOT,
        env=merged,
        capture_output=True,
        text=True,
    )


class RenderSudoers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not RENDER.is_file():
            raise AssertionError(f"missing renderer {RENDER}")

    def test_rule_is_the_installing_user(self):
        for name in ("alice", "omarchy"):
            with self.subTest(user=name):
                result = render(USER=name, SUDO_USER=None)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, f"{name} ALL=(root) NOPASSWD: {CTL}\n")

    def test_prefers_SUDO_USER_when_install_ran_via_sudo(self):
        result = render(USER="root", SUDO_USER="alice")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, f"alice ALL=(root) NOPASSWD: {CTL}\n")

    def test_rejects_root(self):
        result = render(USER="root", SUDO_USER=None)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_rejects_sudoers_metacharacters(self):
        result = render(USER="alice ALL=(ALL) NOPASSWD: ALL #", SUDO_USER=None)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")


class InstallAndCallers(unittest.TestCase):
    def test_install_sh_does_not_copy_static_omarchy_username(self):
        src = (ROOT / "install.sh").read_text()
        self.assertNotIn("sudoers/omarchy-vpn", src)
        self.assertIn("lib/sudoers.sh", src)
        self.assertNotIn('= "omarchy"', src)
        self.assertIn('omneziavpn_render_sudoers "$sudoers_user"', src)

    def test_add_server_invokes_ctl_by_absolute_path(self):
        src = (ROOT / "bin" / "omarchy-vpn-add-server").read_text()
        self.assertIn("sudo -n /usr/local/bin/omarchy-vpn-ctl", src)
        self.assertNotIn("sudo -n omarchy-vpn-ctl", src)


if __name__ == "__main__":
    unittest.main()
