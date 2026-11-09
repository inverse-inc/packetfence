"""Offline CI wiring/source-isolation checks; requires PyYAML."""
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import yaml

ROOT = Path(__file__).resolve().parents[3]
class GitLabLoader(yaml.SafeLoader):
    pass
GitLabLoader.add_constructor('!reference', lambda loader, node: {'reference': loader.construct_sequence(node)})


def load_sources():
    spec = importlib.util.spec_from_file_location('configure_sources', ROOT/'ci/pulp/configure-sources.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ConfigurationTest(unittest.TestCase):
    def test_both_builds_wait_for_the_same_lock_and_both_publish_phases_serialize(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        needs = config['.needs_all_build_images']['needs']
        self.assertIn({'job': 'prepare_pulp_dependencies', 'optional': True, 'artifacts': True}, needs)
        for name in ('build_artifacts_pkg_debian_bookworm', 'build_artifacts_pkg_centos_8'):
            self.assertIn('.build_artifacts_pkg_job', config[name]['extends'])
        prepare, publish = config['prepare_pulp_dependencies'], config['publish_ppa']
        self.assertEqual(prepare['resource_group'], publish['resource_group'])
        self.assertEqual(prepare['artifacts']['reports']['dotenv'], 'pulp.env')
        self.assertIn('pipeline-lock.json', prepare['artifacts']['paths'])
        self.assertIn({'job': 'prepare_pulp_dependencies', 'optional': True, 'artifacts': True}, publish['needs'])
        self.assertEqual(config['variables']['PF_PULP_ENABLED'], 'no')
        self.assertEqual(config['.gated_by_deploy_pkg']['rules'][0],
                         {'if': '$PF_PULP_ENABLED == "yes"', 'when': 'never'})

    def test_container_sync_runs_in_deploy_containers_after_promotion(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        self.assertNotIn('PF_PULP_CONTAINER_SYNC_ENABLED', config['variables'])
        self.assertNotIn('sync_pulp_branch_images', config)
        job = config['deploy_containers']
        self.assertEqual(job['resource_group'], 'pulp-packetfence-containers')
        script = '\n'.join(job['script'])
        # GitHub first, then packages.packetfence.com, which fetches the promoted tags.
        self.assertLess(script.index('promote-images.py'), script.index('ci/pulp/container-sync.sh'))
        self.assertNotIn('PF_PULP_CONTAINER_SYNC_ENABLED', script)
        self.assertEqual(job['artifacts']['expire_in'], '1 day')

    def test_service_images_are_promoted_only_after_tests(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        service = config['.build_img_service_rules']['rules']
        for name in ('pfdebian', 'pfdebian_related', 'radiusd', 'radiusd_related'):
            self.assertIn({'reference': ['.build_img_service_rules', 'rules']}, config[name]['rules'])
        for rule in service:
            if rule['if'] in ('$CI_COMMIT_REF_NAME == "devel"',) or rule['if'].startswith('$CI_COMMIT_REF_NAME =~ /^maintenance'):
                self.assertEqual(rule['variables']['IMAGE_TAGS'], '${CI_COMMIT_REF_SLUG}-p${CI_PIPELINE_ID}')
                self.assertEqual(rule['variables']['BUILDER_TAG'], '${CI_COMMIT_REF_SLUG}')
        job = config['deploy_containers']
        self.assertEqual(job['stage'], 'deploy')
        self.assertNotIn('needs', job)  # waits for every test stage
        for rule in job['rules'][1:]:
            self.assertIn('$TEST == "yes"', rule['if'])
            self.assertIn('$CI_COMMIT_TAG == null', rule['if'])
        self.assertEqual([r['variables']['PROMOTE_TAGS'] for r in job['rules'][1:]],
                         ['${CI_COMMIT_REF_SLUG},latest', '$CI_COMMIT_REF_SLUG'])

    def test_pipeline_image_tag_contexts(self):
        helper = ROOT/'ci/lib/common/pipeline-image-tag.sh'
        base = {'PATH': os.environ['PATH'], 'CI_PIPELINE_ID': '42'}
        cases = [({'CI_COMMIT_REF_NAME': 'devel', 'CI_COMMIT_REF_SLUG': 'devel', 'CI_PIPELINE_SOURCE': 'push'}, 'devel-p42'),
                 ({'CI_COMMIT_REF_NAME': 'maintenance/15.2', 'CI_COMMIT_REF_SLUG': 'maintenance-15-2',
                   'CI_PIPELINE_SOURCE': 'web'}, 'maintenance-15-2-p42'),
                 ({'CI_COMMIT_REF_NAME': 'maintenance/15.2', 'CI_COMMIT_REF_SLUG': 'maintenance-15-2',
                   'CI_PIPELINE_SOURCE': 'push'}, ''),
                 ({'CI_COMMIT_REF_NAME': 'feature/x', 'CI_COMMIT_REF_SLUG': 'feature-x', 'CI_PIPELINE_SOURCE': 'web'}, ''),
                 ({'CI_COMMIT_REF_NAME': 'devel', 'CI_COMMIT_REF_SLUG': 'devel', 'BUILD_IMG_CONTAINER': 'no'}, ''),
                 ({'CI_COMMIT_REF_NAME': 'v16.0.0', 'CI_COMMIT_TAG': 'v16.0.0'}, '')]
        for env, expected in cases:
            result = subprocess.run(['sh', str(helper)], env={**base, **env}, capture_output=True, text=True)
            self.assertEqual((result.returncode, result.stdout.strip()), (0, expected), env)

    def test_container_sync_routes_only_trusted_supported_pipelines(self):
        with tempfile.TemporaryDirectory() as folder:
            work = Path(folder)
            fake_python = work/'python3'
            fake_python.write_text("#!/bin/sh\nprintf '%s|%s|%s|%s|%s\\n' \"$2\" \"$*\" \"$PULP_USERNAME\" \"$PULP_PASSWORD\" \"$PULP_URL\" >> \"$TEST_CALLS\"\n")
            fake_python.chmod(0o700)
            calls = work/'calls'
            cases = [('devel', source, 'true', '', True) for source in ('push', 'web', 'api', 'schedule')]
            cases += [('maintenance/15.2', source, 'true', '', True) for source in ('web', 'api', 'schedule')]
            cases += [('maintenance/15.2', 'push', 'true', '', False),
                      ('maintenance/99.9', 'schedule', 'true', '', False),
                      ('feature/test', 'web', 'true', '', False),
                      ('devel', 'merge_request_event', 'true', '', False),
                      ('devel', 'web', 'false', '', False),
                      ('maintenance/15.2', 'web', 'false', '', False),
                      ('devel', 'web', 'true', 'v16.0.0', False)]
            for branch, source, protected, tag, allowed in cases:
                with self.subTest(branch=branch, source=source, protected=protected, tag=tag):
                    calls.write_text('')
                    env = dict(os.environ, PATH=str(work)+os.pathsep+os.environ['PATH'],
                               TEST_CALLS=str(calls),
                               CI_COMMIT_BRANCH=branch, CI_PIPELINE_SOURCE=source,
                               CI_COMMIT_REF_PROTECTED=protected, CI_COMMIT_TAG=tag,
                               PF_PULP_CONTAINER_USERNAME='test-sync', PF_PULP_CONTAINER_PASSWORD='dummy',
                               PULP_USERNAME='wrong-account', PULP_PASSWORD='wrong-password',
                               PULP_URL='https://pulp.test')
                    result = subprocess.run(['bash', str(ROOT/'ci/pulp/container-sync.sh')],
                                            env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, allowed, result.stderr)
                    recorded = calls.read_text().splitlines()
                    if not allowed:
                        self.assertEqual(recorded, [])
                        continue
                    self.assertEqual(len(recorded), 2)
                    self.assertIn('--branch '+branch, recorded[0])
                    self.assertIn('--allow-tag-update', recorded[1])
                    self.assertIn('--apply', recorded[1])
                    self.assertTrue(all(row.endswith('|test-sync|dummy|https://pulp.test') for row in recorded))

    def test_devel_and_maintenance_plans_select_only_their_published_tags(self):
        with patch.object(sys, 'path', [str(ROOT/'ci/pulp/vendor')] + sys.path):
            spec = importlib.util.spec_from_file_location('container_mirror', ROOT/'ci/pulp/vendor/container_mirror.py')
            mirror = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mirror)
        registry = Mock()
        registry.tags.return_value = {'devel', 'latest', 'maintenance-99-9', 'maintenance-15-2',
                                      'maintenance-14-1', 'cache-build', 'v16.0.0'}
        registry.digest.return_value = 'sha256:'+'a'*64
        for branch, expected in [('devel', {'devel', 'latest', 'maintenance-99-9'}),
                                 ('maintenance/15.2', {'maintenance-15-2'})]:
            plan = mirror.plan({'schema': 1, 'images': ['pfcmd']}, [branch], registry)
            self.assertEqual({entry['tag'] for entry in plan['entries']}, expected)
        registry.tags.return_value = {'latest'}
        plan = mirror.plan({'schema': 1, 'images': ['pfcmd']}, ['devel'], registry)
        self.assertEqual([entry['tag'] for entry in plan['entries']], ['latest'])

    def test_backup_failure_prevents_pulp_publish_and_receipts_are_retained(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        for name in ('prepare_pulp_dependencies', 'publish_ppa'):
            self.assertEqual(config[name]['artifacts']['when'], 'always')
            self.assertIn('package-backup-*.json', config[name]['artifacts']['paths'])
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root/'ci/pulp/vendor').mkdir(parents=True)
            (root/'ci/scripts').mkdir()
            (root/'conf').mkdir()
            (root/'bin').mkdir()
            (root/'ci/pulp/pipeline.sh').write_bytes((ROOT/'ci/pulp/pipeline.sh').read_bytes())
            (root/'conf/pf-release').write_text('PacketFence 16.0.0\n')
            (root/'pipeline-lock.json').write_text('{}')
            (root/'ci/pulp/vendor/helper').write_text('fixture')
            sha = hashlib.sha256(b'fixture').hexdigest()
            (root/'ci/pulp/vendor/SHA256SUMS').write_text(sha + '  helper\n')
            (root/'ci/scripts/generate-pages.sh').write_text('mkdir -p pulp-public\n')
            (root/'ci/pulp/validate-repository.sh').write_text('exit 0\n')
            python = root/'bin/python3'
            python.write_text('''#!/bin/sh
case "$1" in
  *pipeline_repository.py)
    if [ "$2" = fetch ]; then
      mkdir -p pulp-dependencies
      printf '{}' > pulp-dependencies/selection.json
    elif [ "$2" = publish ]; then
      echo PUBLISH >> "$TEST_CALLS"
    fi ;;
  *archive_ci_packages.py)
    echo BACKUP >> "$TEST_CALLS"
    if [ "$TEST_BACKUP_FAIL" = yes ]; then exit 7; fi
    printf '{}' > package-backup-packages.json ;;
  *psono.py) printf 'fixture' ;;
  *check-lock.py) exit 0 ;;
  *) exit 99 ;;
esac
''')
            python.chmod(0o700)
            gpg = root/'bin/gpg'
            gpg.write_text('#!/bin/sh\ncat >/dev/null\n')
            gpg.chmod(0o700)
            calls = root/'calls'
            environment = dict(os.environ, PATH=str(root/'bin') + os.pathsep + os.environ['PATH'],
                TEST_CALLS=str(calls), PF_PULP_ENABLED='yes', CI_COMMIT_REF_PROTECTED='true',
                CI_PIPELINE_ID='123', PF_PACKAGE_ENVIRONMENT='staging', PF_PACKAGE_BACKUP_BUCKET='bucket',
                PF_PACKAGE_BACKUP_ENDPOINT='https://s3.example', PF_PACKAGE_BACKUP_REGION='region',
                PF_PACKAGE_BACKUP_PREFIX='example-archive',
                AWS_ACCESS_KEY_ID='fixture', AWS_SECRET_ACCESS_KEY='fixture', PULP_URL='https://pulp.example',
                PULP_CONTENT_ORIGIN='https://pulp.example', PULP_USERNAME='fixture', PULP_PASSWORD='fixture',
                PF_PULP_REPOSITORY='fixture', PF_PACKAGE_ORIGIN='https://packages.example',
                PSONO_API_KEY_ID='fixture', PSONO_API_KEY_SECRET_KEY='fixture',
                PSONO_GPG_PRIVATE_KEY_SECRET_ID='fixture', GPG_KEY_FINGERPRINT='fixture')
            without_prefix = {key: value for key, value in environment.items()
                              if key != 'PF_PACKAGE_BACKUP_PREFIX'}
            result = subprocess.run(['bash', str(root/'ci/pulp/pipeline.sh'), 'publish'],
                env=without_prefix, cwd=root, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('PF_PACKAGE_BACKUP_PREFIX', result.stderr)
            self.assertFalse(calls.exists())
            for failure in ('yes', 'no'):
                calls.write_text('')
                result = subprocess.run(['bash', str(root/'ci/pulp/pipeline.sh'), 'publish'],
                    env={**environment, 'TEST_BACKUP_FAIL': failure}, cwd=root, capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, failure == 'no', result.stderr)
                self.assertEqual(calls.read_text().splitlines(),
                                 ['BACKUP'] if failure == 'yes' else ['BACKUP', 'PUBLISH'])

    def test_publishing_artifacts_require_project_developer_access(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        for name in ('prepare_pulp_dependencies', 'publish_ppa', 'deploy_containers'):
            self.assertEqual(config[name]['artifacts']['access'], 'developer')
        # Execute every former environment-dump hook with a fake CI secret.
        environment = dict(os.environ, CI_AUDIT_SECRET='must-not-appear-in-job-logs')
        for scope in (config, config['.build_pf_img_vagrant_job'], config['.build_pf_img_job']):
            commands = [line for line in scope['before_script']
                        if line != 'ci/lib/ensure-runner-disk-free.sh']
            result = subprocess.run(['bash', '-c', '\n'.join(commands)],
                                    env=environment, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0)
            self.assertNotIn(environment['CI_AUDIT_SECRET'], result.stdout + result.stderr)

    def test_vendored_helpers_match_recorded_checksums(self):
        vendor = ROOT/'ci/pulp/vendor'
        for line in (vendor/'SHA256SUMS').read_text().splitlines():
            sha, filename = line.split()
            self.assertEqual(hashlib.sha256((vendor/filename).read_bytes()).hexdigest(), sha)

    def test_shell_syntax(self):
        for script in (ROOT/'ci/pulp').rglob('*.sh'):
            subprocess.run(['bash', '-n', str(script)], check=True)
        subprocess.run(['bash', '-n', str(ROOT/'ci/scripts/generate-pages.sh')], check=True)
        subprocess.run(['bash', '-n', str(ROOT/'ci/dvd-usb-iso/create-local-repo.sh')], check=True)

    def test_unprotected_pipeline_fails_before_secrets_or_network(self):
        env = dict(os.environ, PF_PULP_ENABLED='yes', CI_COMMIT_REF_PROTECTED='false')
        result = subprocess.run(['bash', str(ROOT/'ci/pulp/pipeline.sh'), 'prepare'],
                                cwd=ROOT, env=env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('protected ref', result.stderr)

    def test_wrong_release_pipeline_or_commit_lock_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            work = Path(folder)
            (work/'conf').mkdir()
            (work/'conf/pf-release').write_text('PacketFence 16.0.0\n')
            env = dict(os.environ, CI_PIPELINE_ID='123', CI_COMMIT_SHA='abc')
            valid = {'schema': 1, 'release': '16.0', 'pipeline': '123', 'commit': 'abc'}
            for field, value in [('release','15.2'),('pipeline','124'),('commit','def'),('schema',2),('release','16.0')]:
                lock = {**valid, field: value}
                (work/'lock.json').write_text(json.dumps(lock))
                result = subprocess.run([sys.executable, str(ROOT/'ci/pulp/check-lock.py'), 'lock.json'],
                                        cwd=work, env=env, capture_output=True)
                self.assertEqual(result.returncode == 0, lock == valid)


class SourceIsolationTest(unittest.TestCase):
    def test_debian_legacy_and_deb822_sources_removed_without_removing_os(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            sources = root/'etc/apt/sources.list.d'
            sources.mkdir(parents=True)
            (root/'etc/apt/sources.list').write_text('deb https://deb.debian.org/debian bookworm main\n')
            (sources/'mixed.list').write_text('deb https://inverse.ca/downloads/PacketFence/debian/16.0 bookworm bookworm\ndeb https://deb.nodesource.com/node_20.x nodistro main\n')
            (sources/'mixed.sources').write_text('Types: deb\nURIs: https://inverse.ca/downloads/PacketFence/debian/16.0\nSuites: bookworm\nComponents: bookworm\n\nTypes: deb\nURIs: https://deb.debian.org/debian\nSuites: bookworm\nComponents: main\n')
            load_sources().configure('deb', root)
            self.assertTrue((sources/'mixed.list').read_text().startswith('# Pulp CI: deb '))
            self.assertIn('\ndeb https://deb.nodesource.com', (sources/'mixed.list').read_text())
            self.assertNotIn('PacketFence', (sources/'mixed.sources').read_text())
            self.assertIn('deb.debian.org', (sources/'mixed.sources').read_text())
            self.assertTrue((root/'etc/apt/sources.list').read_text().startswith('deb '))

    def test_rpm_only_disables_packetfence_section(self):
        import configparser
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            repos = root/'etc/yum.repos.d'
            repos.mkdir(parents=True)
            file = repos/'mixed.repo'
            file.write_text('[pf]\nbaseurl=https://inverse.ca/downloads/PacketFence/RHEL$releasever/16.0/$basearch\nenabled=1\ngpgcheck=1\n[os]\nbaseurl=https://os.test/$releasever/$basearch\nenabled=1\ngpgcheck=1\n')
            load_sources().configure('rpm', root)
            result = configparser.ConfigParser(interpolation=None)
            result.read(file)
            self.assertEqual(result['pf']['enabled'], '0')
            self.assertEqual(result['os']['enabled'], '1')
            self.assertEqual(result['os']['gpgcheck'], '1')
            self.assertIn('$basearch', result['os']['baseurl'])


if __name__ == '__main__':
    unittest.main()
