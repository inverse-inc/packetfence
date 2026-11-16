"""Offline CI wiring checks; requires PyYAML."""
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[3]
class GitLabLoader(yaml.SafeLoader):
    pass
GitLabLoader.add_constructor('!reference', lambda loader, node: {'reference': loader.construct_sequence(node)})


def push_tree(work):
    """container-push.sh in a copy of the repository whose Psono returns ci-docker / secret-value and logs the call."""
    root = work/'repo'
    (root/'ci/pulp').mkdir(parents=True)
    (root/'addons/packetfence-perl').mkdir(parents=True)
    for name in ('container-push.sh', 'psono-field.sh', 'container-images.json'):
        shutil.copy(ROOT/'ci/pulp'/name, root/'ci/pulp'/name)
    (root/'addons/packetfence-perl/psono.py').write_text(
        'import os, sys\n'
        'open(os.environ["TEST_PSONO"], "a").write(" ".join(a for a in sys.argv[1:] if a.startswith("--secret_id")) + "\\n")\n'
        'print(\'{"website_password_username": "ci-docker", "website_password_password": "secret-value"}\')\n')
    return root/'ci/pulp/container-push.sh'


PSONO_ENV = {'PSONO_CI_API_KEY_ID': 'key', 'PSONO_CI_API_SECRET_KEY_HEX': 'key-secret', 'PSONO_CI_PULP_DOCKER_ID': 'docker-entry',
             'PF_PACKAGE_ORIGIN': 'https://registry.example'}


class ConfigurationTest(unittest.TestCase):
    def test_container_push_runs_in_deploy_containers_after_promotion(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        job = config['deploy_containers']
        self.assertEqual(job['resource_group'], 'pulp-packetfence-containers')
        script = '\n'.join(job['script'])
        # Branches: GitHub first, then the same tags pushed to PF_PACKAGE_ORIGIN. Release tags: push only.
        self.assertLess(script.index('promote-images.py'), script.index('container-push.sh "$pipeline_tag"'))
        self.assertIn('container-push.sh "$pipeline_tag" "$PROMOTE_TAGS"', script)
        self.assertIn('container-push.sh "$CI_COMMIT_TAG" "$CI_COMMIT_TAG"', script)

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
        branches, release = job['rules'][1:-1], job['rules'][-1]
        for rule in branches:
            self.assertIn('$TEST == "yes"', rule['if'])
            self.assertIn('$CI_COMMIT_TAG == null', rule['if'])
        self.assertEqual([r['variables']['PROMOTE_TAGS'] for r in branches],
                         ['${CI_COMMIT_REF_SLUG},latest', '$CI_COMMIT_REF_SLUG'])
        self.assertTrue(release['if'].startswith('$CI_COMMIT_TAG =~ /^v'))

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

    def test_container_push_routes_only_trusted_pipelines_and_never_shows_the_password(self):
        with tempfile.TemporaryDirectory() as folder:
            work = Path(folder)
            # Fake skopeo: pfcmd and radiusd carry the pipeline tag, pfqueue is private, the rest lack the tag.
            fake = work/'skopeo'
            fake.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_CALLS"\n'
                            'case "$*" in "inspect "*) case "$*" in *pfcmd:p-7*|*radiusd:p-7*|*pfcmd:v16.0.0*|*radiusd:v16.0.0*) exit 0;; '
                            '*pfqueue:*) echo "requested access to the resource is denied" >&2; exit 1;; '
                            '*) echo "manifest unknown" >&2; exit 1;; esac;; '
                            '"login "*) cat > "$TEST_LOGIN";; esac\n')
            fake.chmod(0o700)
            script = push_tree(work)
            calls, login, psono = work/'calls', work/'login', work/'psono'
            branch_args = ('p-7', 'devel,latest')
            cases = [('devel', source, 'true', '', branch_args, True) for source in ('push', 'web', 'api', 'schedule')]
            cases += [('maintenance/15.2', source, 'true', '', branch_args, True) for source in ('web', 'api', 'schedule')]
            cases += [('', 'push', 'true', 'v16.0.0', ('v16.0.0', 'v16.0.0'), True),
                      ('maintenance/15.2', 'push', 'true', '', branch_args, False),
                      ('maintenance/99.9', 'schedule', 'true', '', branch_args, False),
                      ('feature/test', 'web', 'true', '', branch_args, False),
                      ('devel', 'merge_request_event', 'true', '', branch_args, False),
                      ('devel', 'web', 'false', '', branch_args, False),
                      ('maintenance/15.2', 'web', 'false', '', branch_args, False),
                      ('devel', 'web', 'true', 'v16.0.0', branch_args, False),
                      ('', 'push', 'false', 'v16.0.0', ('v16.0.0', 'v16.0.0'), False),
                      ('', 'push', 'true', 'v16.0.0', ('v16.0.0', 'latest'), False),
                      ('', 'push', 'true', 'v16.0.0-rc1', ('v16.0.0-rc1', 'v16.0.0-rc1'), False)]
            for branch, source, protected, tag, args, allowed in cases:
                with self.subTest(branch=branch, source=source, protected=protected, tag=tag, args=args):
                    calls.write_text('')
                    psono.write_text('')
                    env = dict(os.environ, **PSONO_ENV, PATH=str(work)+os.pathsep+os.environ['PATH'],
                               TEST_CALLS=str(calls), TEST_LOGIN=str(login), TEST_PSONO=str(psono),
                               CI_COMMIT_BRANCH=branch, CI_PIPELINE_SOURCE=source,
                               CI_COMMIT_REF_PROTECTED=protected, CI_COMMIT_TAG=tag)
                    result = subprocess.run(['bash', str(script), *args], env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, allowed, result.stderr)
                    recorded = calls.read_text().splitlines()
                    if not allowed:
                        self.assertEqual(recorded, [])
                        self.assertEqual(psono.read_text(), '')  # refused before reading Psono
                        continue
                    self.assertEqual(psono.read_text(), '--secret_id=docker-entry\n' * 2)  # username, password
                    self.assertEqual(login.read_text(), 'secret-value')
                    self.assertTrue(recorded[0].startswith('login --authfile '))
                    self.assertIn('--username ci-docker --password-stdin registry.example', recorded[0])
                    copies = [row for row in recorded if row.startswith('copy ')]
                    self.assertTrue(all('--all --preserve-digests' in row for row in copies))
                    if tag:
                        self.assertEqual(len(copies), 2)  # 2 images x the release tag
                        self.assertIn('docker://ghcr.io/inverse-inc/packetfence/pfcmd:v16.0.0 '
                                      'docker://registry.example/inverse-inc/packetfence/pfcmd:v16.0.0', copies[0])
                        continue
                    self.assertEqual(len(copies), 4)  # 2 images x 2 tags
                    self.assertIn('docker://ghcr.io/inverse-inc/packetfence/pfcmd:p-7 '
                                  'docker://registry.example/inverse-inc/packetfence/pfcmd:latest', copies[1])
                    self.assertIn('pfqueue: not public on GHCR (private or not created yet), skipped', result.stdout)
                    self.assertNotIn('pfcron:', result.stdout)  # only lacks this pipeline's tag: silent
                    self.assertFalse(any('secret-value' in row for row in recorded))
                    self.assertNotIn('secret-value', result.stdout + result.stderr)

    def test_every_image_the_pipeline_tags_is_in_the_push_list(self):
        # A service image missing from container-images.json would never reach the registry.
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        listed = set(json.loads((ROOT/'ci/pulp/container-images.json').read_text())['images'])
        built = set()
        for job in config.values():
            if not isinstance(job, dict) or {'reference': ['.build_img_service_rules', 'rules']} not in (job.get('rules') or []):
                continue
            built.add(job.get('variables', {}).get('IMAGE_NAME'))
            for entry in (job.get('parallel') or {}).get('matrix', []):
                names = entry['IMAGE_NAME']
                built.update([names] if isinstance(names, str) else names)
        built.discard(None)
        self.assertGreater(len(built), 30)
        self.assertEqual(sorted(built - listed), [], 'add these images to ci/pulp/container-images.json')

    def test_container_push_refuses_other_tags(self):
        env = dict(os.environ, **PSONO_ENV, CI_COMMIT_BRANCH='devel', CI_PIPELINE_SOURCE='web',
                   CI_COMMIT_REF_PROTECTED='true', CI_COMMIT_TAG='')
        for tags in ('v16.0.0', 'devel,feature-x', 'maintenance-15'):
            result = subprocess.run(['bash', str(ROOT/'ci/pulp/container-push.sh'), 'p-7', tags],
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, tags)
            self.assertIn('Refusing tag', result.stderr)

    def test_publishing_artifacts_require_project_developer_access(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        self.assertEqual(config['publish_ppa']['artifacts']['access'], 'developer')
        self.assertNotIn('artifacts', config['deploy_containers'])  # the push leaves no plan to keep
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

if __name__ == '__main__':
    unittest.main()
