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

    def test_install_sh_requires_resolvconf(self):
        src = (ROOT / "install.sh").read_text()
        self.assertRegex(src, r"for bin in .*\bresolvconf\b")
        self.assertIn("systemd-resolvconf", src)

    def test_install_sh_requires_amneziawg_datapath(self):
        src = (ROOT / "install.sh").read_text()
        self.assertIn("modinfo amneziawg", src)
        self.assertIn("amneziawg-go", src)
        self.assertIn("amneziawg-dkms", src)
        self.assertIn("exit 1", src.split("modinfo amneziawg", 1)[1])

    def test_readme_lists_connect_deps(self):
        src = (ROOT / "README.md").read_text()
        self.assertIn("amneziawg-dkms", src)
        self.assertIn("amneziawg-go", src)
        self.assertIn("systemd-resolvconf", src)


if __name__ == "__main__":
    unittest.main()
