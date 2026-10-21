"""Run with python3 ci/lib/vagrant/test_baked_box_scratch.py."""

import os
from pathlib import Path
import selectors
import subprocess
import tempfile
import time
import unittest


HELPER = Path(__file__).with_name("baked-box-scratch.sh")


class ScratchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="baked-box-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "downloads with spaces"
        self.root.mkdir()

    def start_job(self, child=False):
        script = '''
set -euo pipefail
source "$1"
create_baked_box_work_dir "$2"
touch "$WORK_DIR/box"
echo "$WORK_DIR"
'''
        if child:
            # Child inherits the work-directory lock and remains alive after
            # SIGKILL of its parent, just as an orphaned downloader might.
            script += "bash -c 'echo child-ready; read -r done'\ntrue\n"
        else:
            script += "read -r done\n"
        job = subprocess.Popen(
            ["bash", "-c", script, "test", str(HELPER), str(self.root)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        self.addCleanup(self.stop_job, job)
        work = Path(self.read_line(job))
        if child:
            self.assertEqual(self.read_line(job), "child-ready")
        return job, work

    def read_line(self, job):
        # Read unbuffered bytes so a readiness wait cannot miss buffered lines.
        with selectors.DefaultSelector() as selector:
            selector.register(job.stdout, selectors.EVENT_READ)
            line = bytearray()
            while not line.endswith(b"\n"):
                self.assertTrue(selector.select(5), "job did not become ready")
                byte = os.read(job.stdout.fileno(), 1)
                self.assertTrue(byte, "job exited before becoming ready")
                line.extend(byte)
        return line.decode().strip()

    @staticmethod
    def stop_job(job):
        if job.stdin and not job.stdin.closed:
            try:
                job.stdin.write(b"done\n")
                job.stdin.flush()
            except BrokenPipeError:
                pass
            try:
                job.stdin.close()
            except BrokenPipeError:
                pass
        if job.poll() is None:
            job.wait(timeout=5)
        job.stdout.close()
        job.stderr.close()

    def sweep(self):
        return subprocess.run(
            ["bash", "-euo", "pipefail", "-c",
             'source "$1"; sweep_baked_box_work_dirs "$2"',
             "test", str(HELPER), str(self.root)],
            check=True, capture_output=True, text=True,
        )

    @staticmethod
    def age(path):
        old = time.time() - 7200
        os.utime(path, (old, old))

    def test_active_old_download_survives_and_killed_job_is_reaped(self):
        job, work = self.start_job()
        self.age(work)
        self.sweep()
        self.assertTrue((work / "box").exists())
        job.kill()
        job.wait(timeout=5)
        self.sweep()
        self.assertFalse(work.exists())

    def test_surviving_child_keeps_lock_after_parent_is_killed(self):
        job, work = self.start_job(child=True)
        self.age(work)
        job.kill()
        job.wait(timeout=5)
        self.sweep()
        self.assertTrue(work.exists())
        job.stdin.write(b"done\n")
        job.stdin.flush()
        # EOF on stdout means the child has closed its inherited descriptors.
        with selectors.DefaultSelector() as selector:
            selector.register(job.stdout, selectors.EVENT_READ)
            self.assertTrue(selector.select(5), "child did not exit")
            self.assertEqual(os.read(job.stdout.fileno(), 1), b"")
        self.sweep()
        self.assertFalse(work.exists())

    def test_normal_exit_removes_only_own_directory(self):
        first, first_work = self.start_job()
        second, second_work = self.start_job()
        self.stop_job(first)
        self.assertEqual(first.returncode, 0)
        self.assertFalse(first_work.exists())
        self.assertTrue((second_work / "box").exists())

    def test_young_legacy_and_symlink_entries_are_preserved(self):
        young = self.root / "download.young"
        legacy = self.root / "tmp.legacy"
        target = Path(self.temp.name) / "outside"
        for path in (young, legacy, target):
            path.mkdir()
        self.age(legacy)
        self.age(target)
        link = self.root / "download.link"
        link.symlink_to(target, target_is_directory=True)
        self.sweep()
        for path in (young, legacy, target, link):
            self.assertTrue(path.exists())


if __name__ == "__main__":
    unittest.main()
