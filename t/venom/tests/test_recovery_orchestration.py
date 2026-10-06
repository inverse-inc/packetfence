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

    def test_combined_run_skips_duplicate_sequential_reboot(self):
        result = self.bash('''
SCENARIOS_TO_RUN='cluster_configurator cluster_recovery'
timeout() { echo "CALL $3 [${RECOVERY_SCENARIOS:-}]"; }
run
RECOVERY_SCENARIOS='A C' run
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('CALL run_tests [A B D E F]', result.stdout)
        self.assertIn('CALL run_tests [A C]', result.stdout)

    def recovery_playbook_args(self, recovery_scenarios):
        return self.bash(f'''
SCENARIOS_TO_RUN=cluster_recovery SCENARIOS_BASE_DIR=/nonexistent
RESULT_DIR='' ANSIBLE_VM_LIST=pf1 VAGRANT_PF_DOTFILE_PATH=/dot VENOM_ROOT_DIR=/v
{recovery_scenarios}
run_ansible_galaxy_once() {{ :; }}
stop_resource_sampler() {{ :; }}
ansible-playbook() {{ printf 'ARG %s\\n' "$@"; }}
run_tests
''')

    def test_recovery_scenarios_become_playbook_extra_var(self):
        result = self.recovery_playbook_args("RECOVERY_SCENARIOS='A B D'")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('ARG {"recovery_scenarios": ["A","B","D"]}', result.stdout)

    def test_unset_recovery_scenarios_keep_playbook_default(self):
        result = self.recovery_playbook_args('unset RECOVERY_SCENARIOS')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('recovery_scenarios', result.stdout)

    def test_malformed_recovery_scenarios_are_rejected(self):
        result = self.recovery_playbook_args("RECOVERY_SCENARIOS='A,\"; x'")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('RECOVERY_SCENARIOS must be', result.stderr)
        self.assertNotIn('ARG', result.stdout)

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

    def test_local_baked_box_opt_in_maps_localdev(self):
        result = self.bash('''
LOCAL_BAKED_BOX=yes
for vm in pf1deb12localdev pfdeb12localdev pf3el8localdev pf1deb12dev pfdeb12; do
    echo "$vm=$(baked_box_for_pf_vm "$vm")"
done
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            'pf1deb12localdev=pfdeb12localdev', 'pfdeb12localdev=pfdeb12localdev',
            'pf3el8localdev=pfel8localdev', 'pf1deb12dev=pfdeb12dev', 'pfdeb12='])

    def baked_import_calls(self, vms):
        return self.bash(f'''
set -o errexit
VAGRANT_DIR=/tmp VAGRANT_PF_DOTFILE_PATH=/dot VAGRANT_UP_OPTS=''
log_subsection() {{ :; }}
filter_vagrant_progress() {{ cat; }}
vagrant() {{ echo "VAGRANT $*"; }}
ansible-playbook() {{ echo "PLAY $*"; }}
start_baked_pf_vms {vms}
echo END
''')

    def test_baked_import_boots_together_and_runs_playbooks_once(self):
        result = self.baked_import_calls('pf1deb12localdev pf2deb12localdev pf3deb12localdev')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            'VAGRANT up pf1deb12localdev pf2deb12localdev pf3deb12localdev',
            'PLAY playbooks/cluster_prep_baked.yml -l pf1deb12localdev,pf2deb12localdev,pf3deb12localdev',
            'PLAY playbooks/refresh_network_post_import.yml -l pf1deb12localdev,pf2deb12localdev,pf3deb12localdev',
            'PLAY playbooks/cluster_readdress_baked.yml -l pf1deb12localdev,pf2deb12localdev,pf3deb12localdev',
            'PLAY playbooks/register_rhel_subscription.yml -l pf1deb12localdev,pf2deb12localdev,pf3deb12localdev',
            'END'])

    def test_baked_import_of_a_standalone_skips_cluster_playbooks(self):
        result = self.baked_import_calls('pfdeb12dev')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            'VAGRANT up pfdeb12dev',
            'PLAY playbooks/refresh_network_post_import.yml -l pfdeb12dev',
            'PLAY playbooks/register_rhel_subscription.yml -l pfdeb12dev',
            'END'])

    def guarded_baked_startup(self, vms, fallback='no', local='no', fail_vm=''):
        return self.bash(f'''
VAGRANT_DIR=/tmp VAGRANT_PF_DOTFILE_PATH=/nonexistent VAGRANT_UP_OPTS=''
USE_VAGRANT_BOX=yes SKIP_CONFIGURATOR_BAKED=yes
FALLBACK_TO_FULL_PROVISION={fallback} LOCAL_BAKED_BOX={local}
run_ansible_galaxy_once() {{ :; }}
register_vagrant_box_or_fallback() {{
    echo "REGISTER $1"
    if [ "$1" = "{fail_vm}" ]; then
        maybe_fallback_to_full_provision 'simulated registration failure'
    fi
}}
start_baked_pf_vms() {{ echo "BAKED $*"; }}
prefetch_private_box() {{ :; }}
wait_for_ssh() {{ :; }}
vagrant() {{ echo "VAGRANT $* USE=$USE_VAGRANT_BOX"; }}
ansible-playbook() {{ echo "PROVISION $* USE=$USE_VAGRANT_BOX CONFIGURATOR=$SKIP_CONFIGURATOR_BAKED"; }}
start_and_provision_pf_vm {vms}
''')

    def test_batch_start_validates_every_box_before_import(self):
        result = self.guarded_baked_startup('pf1deb12dev pf2deb12dev pf3deb12dev')
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [line for line in result.stdout.splitlines()
                 if line.startswith(('REGISTER ', 'BAKED '))]
        self.assertEqual(calls, ['REGISTER pf1deb12dev', 'REGISTER pf2deb12dev',
                                 'REGISTER pf3deb12dev',
                                 'BAKED pf1deb12dev pf2deb12dev pf3deb12dev'])

    def test_unmapped_node_prevents_any_batch_import(self):
        for vms in ['pfdeb12 pf1deb12dev', 'pf1deb12dev pfdeb12']:
            with self.subTest(vms=vms):
                result = self.guarded_baked_startup(vms)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('no baked box for:', result.stderr)
                self.assertNotIn('REGISTER ', result.stdout)
                self.assertNotIn('BAKED ', result.stdout)
                self.assertNotIn('VAGRANT ', result.stdout)

    def test_unmapped_node_falls_back_for_the_entire_batch(self):
        result = self.guarded_baked_startup('pf1deb12dev pfdeb12', fallback='yes')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('BAKED ', result.stdout)
        self.assertIn('PROVISION site.yml -l pf1deb12dev,pfdeb12 USE=no CONFIGURATOR=no',
                      result.stdout)

    def test_local_opt_in_keeps_batch_import(self):
        result = self.guarded_baked_startup('pf1deb12localdev pf2deb12localdev', local='yes')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('BAKED pf1deb12localdev pf2deb12localdev', result.stdout)

    def test_later_registration_failure_happens_before_any_batch_import(self):
        for fallback in ['yes', 'no']:
            with self.subTest(fallback=fallback):
                result = self.guarded_baked_startup('pf1deb12dev pf2el8dev',
                                                   fallback=fallback, fail_vm='pf2el8dev')
                self.assertEqual(result.returncode == 0, fallback == 'yes', result.stderr)
                self.assertNotIn('BAKED ', result.stdout)
                if fallback == 'yes':
                    self.assertIn('PROVISION site.yml -l pf1deb12dev,pf2el8dev USE=no CONFIGURATOR=no',
                                  result.stdout)
                else:
                    self.assertNotIn('VAGRANT ', result.stdout)

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
