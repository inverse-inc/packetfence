"""Run HA assertions with Ansible and fake systemctl/mysql, without cluster VMs.

Requires ansible-core and PyYAML in the test environment.
"""
import json
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[3]
SCENARIOS = ROOT / 't/venom/scenarios'
RECOVERY = SCENARIOS / 'cluster_recovery/playbooks/tasks'


@unittest.skipUnless(shutil.which('ansible-playbook'), 'ansible-core is required')
class ClusterHAGuards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='ha-guards-')
        self.addCleanup(self.temp.cleanup)
        self.directory = pathlib.Path(self.temp.name)
        self.calls = self.directory / 'calls.jsonl'
        self.marker = self.directory / 'assertions-passed'
        self.config = self.directory / 'ansible.cfg'
        self.config.write_text('[defaults]\n')
        self.bin = self.directory / 'bin'
        self.bin.mkdir()
        stub = '''import json, os, pathlib, sys
with open(os.environ['HA_CALLS'], 'a') as log:
    log.write(json.dumps(sys.argv) + '\\n')
responses = json.loads(os.environ['HA_RESPONSES'])
key = 'systemctl' if pathlib.Path(sys.argv[0]).name == 'systemctl' else sys.argv[-1].split()[0]
response = responses[key]
sys.stdout.write(response.get('stdout', ''))
sys.stderr.write(response.get('stderr', ''))
sys.exit(response.get('rc', 0))
'''
        for command in ['systemctl', 'mysql']:
            path = self.bin / command
            path.write_text(f'#!{sys.executable}\n' + stub)
            path.chmod(0o755)

    def run_tasks(self, tasks, responses, variables=None):
        # Exercise the real task conditions, but don't wait minutes on deliberate
        # failures. The marker must never be reached when an assertion fails.
        for task in tasks:
            if 'until' in task:
                task.update(retries=1, delay=0)
        tasks.append({'ansible.builtin.copy': {
            'dest': str(self.marker), 'content': 'passed'}})
        play = [{'hosts': 'localhost', 'gather_facts': False,
                 'vars': variables or {}, 'tasks': tasks}]
        path = self.directory / 'play.yml'
        path.write_text(yaml.safe_dump(play))
        self.calls.unlink(missing_ok=True)
        environment = dict(os.environ, ANSIBLE_CONFIG=str(self.config),
                           ANSIBLE_NOCOLOR='1',
                           PATH=f'{self.bin}:{os.environ["PATH"]}',
                           HA_CALLS=str(self.calls), HA_RESPONSES=json.dumps(responses))
        return subprocess.run([
            'ansible-playbook', '-i', 'localhost,', '-c', 'local',
            '-e', f'ansible_python_interpreter={sys.executable}', str(path)
        ], text=True, capture_output=True, env=environment, cwd=self.directory,
            timeout=60)

    def assert_outcome(self, result, success):
        self.assertTrue(self.calls.exists(), result.stdout + result.stderr)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        self.assertEqual(self.marker.exists(), success)
        self.marker.unlink(missing_ok=True)

    def test_service_states_reject_errors_missing_units_and_failed_stops(self):
        path = SCENARIOS / 'cluster_failover/playbooks/tasks/failover/wait_unit_state.yml'
        for expected, state, load, result, rc, success in [
            ('inactive', 'inactive', 'loaded', 'success', 0, True),
            ('active', 'active', 'loaded', 'success', 0, True),
            ('inactive', 'active', 'loaded', 'success', 0, False),
            ('inactive', 'deactivating', 'loaded', 'success', 0, False),
            ('inactive', 'inactive', 'not-found', 'success', 0, False),
            ('inactive', 'failed', 'loaded', 'timeout', 0, False),
            ('inactive', 'inactive', 'loaded', 'timeout', 0, False),
            ('inactive', '', '', '', 1, False),
            ('active', 'inactive', 'loaded', 'success', 0, False),
        ]:
            with self.subTest(expected=expected, state=state, load=load, result=result, rc=rc):
                response = {'rc': rc, 'stdout':
                            f'LoadState={load}\nActiveState={state}\nResult={result}\n'}
                run = self.run_tasks(yaml.safe_load(path.read_text()),
                                     {'systemctl': response},
                                     {'unit_host': 'localhost', 'unit_name': 'packetfence-pfdhcp',
                                      'unit_state': expected})
                self.assert_outcome(run, success)




if __name__ == '__main__':
    unittest.main()
