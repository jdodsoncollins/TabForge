import importlib.util
from pathlib import Path
import stat
import tempfile
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "configure-build.py"
SPEC = importlib.util.spec_from_file_location("configure_build", MODULE_PATH)
configure_build = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(configure_build)


class LocalBuildConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.env = self.root / ".env"

    def write(self, bundle="org.example.Editor", team=""):
        self.env.write_text(
            f"TABFORGE_DEVELOPMENT_TEAM={team}\n"
            f"TABFORGE_BUNDLE_IDENTIFIER={bundle}\n",
            encoding="utf-8",
        )

    def test_another_authors_configuration_is_written_privately(self):
        self.write(bundle="net.example.CodeKeys", team="AB12CD34EF")
        values = configure_build.read_configuration(self.env)
        output = self.root / "Signing.local.xcconfig"
        configure_build.write_configuration(output, configure_build.render_configuration(values))
        content = output.read_text()
        self.assertIn("TABFORGE_BUNDLE_IDENTIFIER = net.example.CodeKeys\n", content)
        self.assertIn("DEVELOPMENT_TEAM = AB12CD34EF\n", content)
        self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o600)

    def test_shell_and_xcode_expansions_are_rejected_without_execution(self):
        sentinel = self.root / "executed"
        for value in (f"$(touch {sentinel})", f"`touch {sentinel}`", "${BUNDLE_ID}", "org.example.App // injected", "org.example.App;uname"):
            with self.subTest(value=value):
                self.write(bundle=value)
                with self.assertRaises(configure_build.ConfigurationError):
                    configure_build.read_configuration(self.env)
        self.assertFalse(sentinel.exists())

    def test_invalid_or_ambiguous_inputs_fail_closed(self):
        invalid_inputs = (
            "TABFORGE_BUNDLE_IDENTIFIER=org.example.Editor\n",
            "UNKNOWN=foo\n",
            "TABFORGE_BUNDLE_IDENTIFIER=org.example.Editor\nTABFORGE_BUNDLE_IDENTIFIER=net.example.Other\n",
        )
        for content in invalid_inputs:
            with self.subTest(content=content):
                self.env.write_text(content, encoding="utf-8")
                with self.assertRaises(configure_build.ConfigurationError):
                    configure_build.read_configuration(self.env)
        for overrides in ({"team": "lowercase1"}, {"bundle": "org..Editor"}, {"bundle": "org.example.*"}):
            with self.subTest(overrides=overrides):
                self.write(**overrides)
                with self.assertRaises(configure_build.ConfigurationError):
                    configure_build.read_configuration(self.env)

    def test_simulator_configuration_and_literal_quotes_are_accepted(self):
        self.write(bundle='"org.example.Editor"')
        values = configure_build.read_configuration(self.env)
        self.assertEqual(values["TABFORGE_DEVELOPMENT_TEAM"], "")
        self.assertEqual(values["TABFORGE_BUNDLE_IDENTIFIER"], "org.example.Editor")

    def test_symlink_output_does_not_modify_its_target(self):
        target = self.root / "keep.txt"
        target.write_text("keep", encoding="utf-8")
        output = self.root / "Signing.local.xcconfig"
        output.symlink_to(target)
        with self.assertRaises(configure_build.ConfigurationError):
            configure_build.write_configuration(output, "replacement")
        self.assertEqual(target.read_text(), "keep")


if __name__ == "__main__":
    unittest.main()
