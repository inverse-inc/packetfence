"""Offline regression tests: python3 -m unittest discover -s ci/lib/tests -v."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / "ansible-galaxy-cache.sh"


class GalaxyCacheTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="galaxy cache ")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.req = self.root / "requirements.yml"
        self.req.write_text("roles: []\ncollections: []\n")
        self.config = self.root / "ansible.cfg"
        self.config.write_text("[defaults]\n")
        self.log = self.root / "calls.jsonl"
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        ANSIBLE_GALAXY_CACHE_DIR=str(self.root / "cache"),
                        ANSIBLE_GALAXY_SEED_DIR=str(self.root / "seed"),
                        FAKE_LOG=str(self.log))
        fake = self.bin / "ansible-galaxy"
        fake.write_text(f"#!{sys.executable}\n" + r'''
import json, os, pathlib, sys, time
args = sys.argv[1:]
assert args[0] in ("role", "collection") and args[1] == "install", args
assert "--force" not in args
path = args[args.index("-p") + 1]
expected = os.environ["ANSIBLE_ROLES_PATH" if args[0] == "role" else "ANSIBLE_COLLECTIONS_PATH"]
assert path == expected
assert os.environ["ANSIBLE_COLLECTIONS_PATH"] == os.environ["ANSIBLE_COLLECTIONS_PATHS"]
assert pathlib.Path(os.environ["ANSIBLE_CONFIG"]).is_file()
with open(os.environ["FAKE_LOG"], "a") as log:
    log.write(json.dumps(args) + "\n")
time.sleep(0.05)
if os.environ.get("FAKE_FAIL") == args[0]:
    sys.exit(1)
(pathlib.Path(path) / "installed").write_text("ok")
''')
        fake.chmod(0o755)
        # Retry timing is irrelevant to these tests.
        sleep = self.bin / "sleep"
        sleep.write_text("#!/bin/sh\nexit 0\n")
        sleep.chmod(0o755)

    def command(self, requirements=None, command=None):
        return ["bash", str(HELPER), str(requirements or self.req), str(self.config),
                *(command or [sys.executable, "-c",
                  "import json, os; print(json.dumps(dict(os.environ)))"])]

    def run_helper(self, requirements=None, command=None):
        return subprocess.run(self.command(requirements, command), env=self.env,
                              text=True, capture_output=True, check=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_cold_install_then_offline_hit(self):
        result = json.loads(self.run_helper().stdout)
        roles = Path(result["ANSIBLE_ROLES_PATH"])
        collections = Path(result["ANSIBLE_COLLECTIONS_PATH"])
        self.assertTrue((roles / "installed").exists())
        self.assertTrue((collections / "installed").exists())
        self.assertEqual(result["ANSIBLE_CONFIG"], str(self.config))
        self.assertNotIn(".tmp.", str(roles))
        self.env["FAKE_FAIL"] = "role"
        self.run_helper()
        self.assertEqual(len(self.calls()), 2)

    def test_changed_requirements_and_rollback(self):
        original = self.req.read_text()
        first = json.loads(self.run_helper().stdout)["ANSIBLE_ROLES_PATH"]
        self.req.write_text(original + "# new version\n")
        second = json.loads(self.run_helper().stdout)["ANSIBLE_ROLES_PATH"]
        self.assertNotEqual(first, second)
        self.req.write_text(original)
        self.assertEqual(first, json.loads(self.run_helper().stdout)["ANSIBLE_ROLES_PATH"])
        self.assertEqual(len(self.calls()), 4)

    def test_identical_requirements_in_another_checkout(self):
        self.run_helper()
        other = self.root / "other.yml"
        other.write_text(self.req.read_text())
        self.run_helper(other)
        self.assertEqual(len(self.calls()), 2)

    def test_failure_is_not_cached_and_command_does_not_run(self):
        self.env["FAKE_FAIL"] = "collection"
        result = subprocess.run(self.command(), env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertEqual(len(self.calls()), 6)
        self.assertEqual(list((self.root / "cache").rglob(".complete")), [])
        self.assertEqual(list((self.root / "cache").rglob("*.tmp.*")), [])
        del self.env["FAKE_FAIL"]
        self.run_helper()
        self.assertEqual(len(self.calls()), 8)

    def test_concurrent_jobs_install_only_once(self):
        processes = [subprocess.Popen(self.command(), env=self.env, text=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                     for _ in range(3)]
        results = []
        for process in processes:
            stdout, stderr = process.communicate(timeout=10)
            self.assertEqual(process.returncode, 0, stderr)
            results.append(json.loads(stdout)["ANSIBLE_ROLES_PATH"])
        self.assertEqual(len(set(results)), 1)
        self.assertEqual(len(self.calls()), 2)

    def test_image_seed_avoids_installation(self):
        self.env["ANSIBLE_GALAXY_CACHE_DIR"] = self.env["ANSIBLE_GALAXY_SEED_DIR"]
        first = json.loads(self.run_helper().stdout)["ANSIBLE_ROLES_PATH"]
        self.env["ANSIBLE_GALAXY_CACHE_DIR"] = str(self.root / "runtime")
        self.assertEqual(first, json.loads(self.run_helper().stdout)["ANSIBLE_ROLES_PATH"])
        self.assertEqual(len(self.calls()), 2)
        self.assertFalse((self.root / "runtime").exists())

    def test_sourced_helper_switches_between_requirements(self):
        other = self.root / "other.yml"
        other.write_text(self.req.read_text() + "# scenario dependencies\n")
        script = '''set -euo pipefail
source "$1"
cd /
prepare_ansible_dependencies "$2" "$4"
first=$ANSIBLE_ROLES_PATH
prepare_ansible_dependencies "$3" "$4"
[[ $first != "$ANSIBLE_ROLES_PATH" ]]
prepare_ansible_dependencies "$2" "$4"
[[ $first == "$ANSIBLE_ROLES_PATH" ]]
'''
        subprocess.run(["bash", "-c", script, "test", str(HELPER), str(self.req),
                        str(other), str(self.config)], env=self.env, check=True,
                       capture_output=True, text=True)
        self.assertEqual(len(self.calls()), 4)

    def test_command_failure_is_preserved(self):
        result = subprocess.run(self.command(command=["bash", "-c", "exit 42"]),
                                env=self.env, capture_output=True)
        self.assertEqual(result.returncode, 42)


if __name__ == "__main__":
    unittest.main()
