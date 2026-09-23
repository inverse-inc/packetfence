"""Exercise orchestration without starting VMs or accessing the network."""
import pathlib
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
WRAPPER = (ROOT / 't/venom/test-wrapper.sh').read_text().split('\nconfigure_and_check\n')[0]


class RecoveryOrchestration(unittest.TestCase):
    def bash(self, commands):
        return subprocess.run(['bash', '-c', WRAPPER + '\n' + commands],
                              text=True, capture_output=True, cwd=ROOT)

    def test_separate_budgets_and_recovery_only_environment(self):
        result = self.bash('''
SCENARIOS_TO_RUN='cluster_configurator cluster_recovery'
CLUSTER_SETUP_TIMEOUT=12m CLUSTER_RECOVERY_TIMEOUT=34m
timeout() { printf 'CALL %s %s %s\\n' "$1" "$3" "$SCENARIOS_TO_RUN"; }
run
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [line for line in result.stdout.splitlines() if line.startswith('CALL ')]
        self.assertEqual(calls, ['CALL 12m prepare_cluster cluster_configurator cluster_recovery',
                                 'CALL 34m run_tests cluster_recovery'])

    def test_setup_timeout_prevents_recovery(self):
        result = self.bash('''
SCENARIOS_TO_RUN='cluster_configurator cluster_recovery'
timeout() { echo "CALL $3"; return 124; }
run
''')
        self.assertEqual(result.returncode, 124)
        self.assertIn('CALL prepare_cluster', result.stdout)
        self.assertNotIn('CALL run_tests', result.stdout)

    def test_cluster_clone_box_mapping_excludes_local_and_release(self):
        result = self.bash('''
for vm in pfdeb12dev pf1deb12dev pf3el8dev pf1deb12localdev pfdeb12; do
    echo "$vm=$(baked_box_for_pf_vm "$vm")"
done
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            'pfdeb12dev=pfdeb12dev', 'pf1deb12dev=pfdeb12dev',
            'pf3el8dev=pfel8dev', 'pf1deb12localdev=', 'pfdeb12='])

    def test_ordinary_runs_keep_existing_scenario_path(self):
        result = self.bash('''
SCENARIOS_TO_RUN=configurator PF_VM_NAMES=pfdeb12dev INT_TEST_VM_NAMES=''
check_free_space() { :; }
start_and_provision_pf_vm() { echo "PROVISION $*"; }
run_tests() { echo "SCENARIO $SCENARIOS_TO_RUN"; }
timeout() { echo UNEXPECTED; return 99; }
run
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('PROVISION pfdeb12dev', result.stdout)
        self.assertIn('SCENARIO configurator', result.stdout)
        self.assertNotIn('UNEXPECTED', result.stdout)


if __name__ == '__main__':
    unittest.main()
