#!/usr/bin/env python3
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


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
