"""Offline CI wiring checks; requires PyYAML."""
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[3]
# The scripts under test call python3 from PATH: make it the interpreter running the tests (EL8's is 3.6).
_PYTHON_DIR = tempfile.mkdtemp(prefix='python3-')
os.symlink(sys.executable, os.path.join(_PYTHON_DIR, 'python3'))
os.environ['PATH'] = _PYTHON_DIR + os.pathsep + os.environ['PATH']

class GitLabLoader(yaml.SafeLoader):
    pass
GitLabLoader.add_constructor('!reference', lambda loader, node: {'reference': loader.construct_sequence(node)})


def resolved_rules(config, name):
    """A job's rules as GitLab sees them: inherited through extends, !reference expanded."""
    job = config[name]
    rules = job.get('rules')
    if rules is None:
        for parent in reversed(job.get('extends', [])):
            rules = resolved_rules(config, parent)
            if rules:
                break
    out = []
    for rule in rules or []:
        if 'reference' in rule:
            target, key = rule['reference']
            out.extend(config[target][key])
        else:
            out.append(rule)
    return out


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
        # GitHub first, then the same tags pushed to PF_PACKAGE_ORIGIN; a release tag pushes nothing there.
        # A feature branch promotes nothing and pushes its pipeline tag.
        self.assertLess(script.index('promote-images.py'), script.index('container-push.sh "$pipeline_tag"'))
        self.assertIn('container-push.sh "$pipeline_tag" "${PROMOTE_TAGS:-$pipeline_tag}"', script)
        feature = [r for r in job['rules'] if isinstance(r, dict) and '$CI_COMMIT_REF_NAME != "devel"' in r.get('if', '')]
        self.assertEqual([r['variables']['PROMOTE_TAGS'] for r in feature], [''])
        self.assertIn('$DEPLOY_PKG == "yes"', feature[0]['if'])
        self.assertNotIn('CI_COMMIT_TAG', script)

    def test_service_images_are_promoted_whenever_packages_are_published(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        service = config['.build_img_service_rules']['rules']
        for name in ('pfdebian', 'pfdebian_related', 'radiusd', 'radiusd_related'):
            self.assertIn({'reference': ['.build_img_service_rules', 'rules']}, config[name]['rules'])
        for rule in service:
            if rule['if'] != '$CI_COMMIT_TAG':  # every branch: devel, maintenance/X.Y, feature branches
                self.assertEqual(rule['variables']['IMAGE_TAGS'], '${CI_COMMIT_REF_SLUG}-p${CI_PIPELINE_ID}')
                self.assertEqual(rule['variables']['BUILDER_TAG'], '${CI_COMMIT_REF_SLUG}')
        job = config['deploy_containers']
        # Its own stage right after deploy, no needs: it waits for the tests and for the package deploys,
        # and runs only if they succeeded; the gates below keep it out of pipelines that built no images.
        stages = config['stages']
        self.assertEqual(job['stage'], 'deploy_images')
        self.assertEqual(stages.index('deploy_images'), stages.index('deploy') + 1)
        self.assertNotIn('needs', job)
        self.assertEqual(job['rules'][:2], [{'reference': ['.gated_by_build_img_container', 'rules']},
                                            {'reference': ['.gated_by_deploy_pkg', 'rules']}])
        branches = job['rules'][2:4]
        packages = [r['if'] for r in config['deploy_debian_pulp']['rules'] if 'if' in r]
        # Promotion matches the packages condition for condition: a pipeline that publishes one
        # publishes the other, with or without tests. The tag guard is promotion's alone.
        self.assertEqual([r['if'] for r in branches], [packages[0] + ' && $CI_COMMIT_TAG == null'] + packages[1:])
        feature = [r['if'] for r in config['deploy_branches_pulp']['rules'] if 'if' in r]
        self.assertEqual([r['if'] for r in job['rules'][4:]], feature)
        for rule in branches:
            self.assertNotIn('$TEST', rule['if'])
            self.assertIn('$CI_COMMIT_TAG == null', rule['if'])
        self.assertEqual([r['variables']['PROMOTE_TAGS'] for r in branches],
                         ['${CI_COMMIT_REF_SLUG},latest', '$CI_COMMIT_REF_SLUG'])

    def test_service_images_build_from_the_builder_branch_tag(self):
        # Service images get a pipeline tag (IMAGE_TAG); pfbuild-* builders only have their branch tag.
        wrong = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'containers').glob('*/Dockerfile')
                       if any(l.startswith('FROM') and '/pfbuild-' in l and '${IMAGE_TAG}' in l
                              for l in p.read_text().splitlines()))
        self.assertEqual(wrong, [], 'use FROM .../pfbuild-*:${BUILDER_TAG} (with ARG BUILDER_TAG)')
        # kanikobuild passes only the DOCKFILE_VARS as build arguments: without it, BUILDER_TAG is empty.
        passed = re.search(r"^DOCKFILE_VARS='([^']*)'", (ROOT/'containers/kaniko_vars').read_text(), re.M).group(1).split()
        self.assertIn('BUILDER_TAG', passed)
        # pfdebian takes the dependencies from the package origin, not from the old inverse.ca host.
        self.assertIn('PF_PACKAGE_ORIGIN', passed)
        self.assertNotIn('inverse.ca', (ROOT/'containers/pfdebian/Dockerfile').read_text())
        # Installers and shipped scripts read the package origin; nothing updates inverse.ca after this change.
        for pattern in ('ci/*installer*/*', 'ci/cd-iso/*', 'ci/dvd-usb-iso/*', 'addons/full-upgrade/*',
                        'addons/monit/monitoring-scripts/setup.sh'):
            for path in ROOT.glob(pattern):
                if path.is_file():
                    self.assertNotIn('inverse.ca/downloads', path.read_text(errors='replace'), path)

    def test_pipeline_image_tag_contexts(self):
        helper = ROOT/'ci/lib/common/pipeline-image-tag.sh'
        base = {'PATH': os.environ['PATH'], 'CI_PIPELINE_ID': '42'}
        cases = [({'CI_COMMIT_REF_NAME': 'devel', 'CI_COMMIT_REF_SLUG': 'devel', 'CI_PIPELINE_SOURCE': 'push'}, 'devel-p42'),
                 ({'CI_COMMIT_REF_NAME': 'maintenance/15.2', 'CI_COMMIT_REF_SLUG': 'maintenance-15-2',
                   'CI_PIPELINE_SOURCE': 'web'}, 'maintenance-15-2-p42'),
                 ({'CI_COMMIT_REF_NAME': 'maintenance/15.2', 'CI_COMMIT_REF_SLUG': 'maintenance-15-2',
                   'CI_PIPELINE_SOURCE': 'push'}, ''),
                 ({'CI_COMMIT_REF_NAME': 'feature/x', 'CI_COMMIT_REF_SLUG': 'feature-x', 'CI_PIPELINE_SOURCE': 'web'}, 'feature-x-p42'),
                 ({'CI_COMMIT_REF_NAME': 'feature/x', 'CI_COMMIT_REF_SLUG': 'feature-x', 'CI_PIPELINE_SOURCE': 'push'}, ''),
                 ({'CI_COMMIT_REF_NAME': 'devel', 'CI_COMMIT_REF_SLUG': 'devel', 'BUILD_IMG_CONTAINER': 'no'}, ''),
                 ({'CI_COMMIT_REF_NAME': 'v16.0.0', 'CI_COMMIT_TAG': 'v16.0.0'}, '')]
        for env, expected in cases:
            result = subprocess.run(['sh', str(helper)], env={**base, **env}, capture_output=True, text=True)
            self.assertEqual((result.returncode, result.stdout.strip()), (0, expected), env)

    def test_packages_pull_the_tag_their_images_keep(self):
        # A feature branch's images keep the pipeline tag; devel/maintenance get their branch tag.
        helper = ROOT/'ci/lib/common/image-tag.sh'
        base = {'PATH': os.environ['PATH'], 'CI_PIPELINE_ID': '42', 'CI_PIPELINE_SOURCE': 'web'}
        cases = [({'CI_COMMIT_REF_NAME': 'feature/x', 'CI_COMMIT_REF_SLUG': 'feature-x'}, 'feature-x-p42'),
                 ({'CI_COMMIT_REF_NAME': 'feature/x', 'CI_COMMIT_REF_SLUG': 'feature-x', 'BUILD_IMG_CONTAINER': 'no'}, 'feature-x'),
                 ({'CI_COMMIT_REF_NAME': 'devel', 'CI_COMMIT_REF_SLUG': 'devel'}, 'devel'),
                 ({'CI_COMMIT_REF_NAME': 'maintenance/15.2', 'CI_COMMIT_REF_SLUG': 'maintenance-15-2'}, 'maintenance-15-2'),
                 ({'CI_COMMIT_REF_NAME': 'v16.0.0', 'CI_COMMIT_TAG': 'v16.0.0'}, 'v16.0.0'),
                 ({}, '')]
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
                            '"login "*) python3 -c \'import json, sys; json.load(open(sys.argv[1]))\' "$3" || exit 1; cat > "$TEST_LOGIN";; esac\n')
            fake.chmod(0o700)
            script = push_tree(work)
            calls, login, psono = work/'calls', work/'login', work/'psono'
            branch_args = ('p-7', 'devel,latest')
            cases = [('devel', source, 'true', '', branch_args, True) for source in ('push', 'web', 'api', 'schedule')]
            cases += [('maintenance/15.2', source, 'true', '', branch_args, True) for source in ('web', 'api', 'schedule')]
            cases += [('', 'push', 'true', 'v16.0.0', ('v16.0.0', 'v16.0.0'), False),  # a release tag stays on GitHub
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

    def test_packages_are_published_to_pulp_only(self):
        text = (ROOT/'.gitlab-ci.yml').read_text()
        config = yaml.load(text, Loader=GitLabLoader)
        # A release tag publishes nothing: its packages came from maintenance/X.Y, its images stay on GitHub.
        for job in ('deploy_debian_pulp', 'deploy_containers', 'deploy_branches_pulp'):
            self.assertNotIn('$CI_COMMIT_TAG', [r.get('if') for r in config[job]['rules'] if isinstance(r, dict)])
            self.assertFalse(any('$CI_COMMIT_TAG =~' in (r.get('if') or '') for r in config[job]['rules'] if isinstance(r, dict)))
        self.assertNotIn('$CI_COMMIT_TAG', [r.get('if') for r in config['.deploy_pkg_rules']['rules']])
        for gone in ('deploy_packages', 'deploy_website_artifacts', 'build_artifacts_website', '.deploy_packages_job'):
            self.assertNotIn(gone, config)
        for word in ('PF_PULP_PUBLISH', 'deploy-artifacts.sh', 'web.inverse.ca', 'PSONO_SSH_DEPLOY_KEY'):
            self.assertNotIn(word, text)
        files = config['deploy_files_pulp']
        self.assertIn({'reference': ['.deploy_pkg_rules', 'rules']}, files['rules'])
        self.assertEqual(files['script'], ['bash ci/pulp/publish-packages.sh files'])

    def test_feature_branches_deploy_with_deploy_pkg_yes_or_true(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        # Its packages (deploy_branches_pulp) and its pipeline-tagged images (deploy_containers), on request only.
        feature = [r['if'] for job in ('deploy_branches_pulp', 'deploy_containers') for r in config[job]['rules']
                   if isinstance(r, dict) and '$CI_COMMIT_REF_NAME != "devel"' in r.get('if', '')]
        self.assertEqual(len(feature), 2)
        for rule in feature:
            for wanted in ('$DEPLOY_PKG == "yes"', '$DEPLOY_PKG == "true"'):
                self.assertIn(wanted, rule)
        self.assertNotIn('PUBLISH_PPA', (ROOT/'.gitlab-ci.yml').read_text())  # DEPLOY_PKG is the only switch
        self.assertEqual(config['.gated_by_deploy_pkg']['rules'][0]['if'], '$DEPLOY_PKG == "no" || $DEPLOY_PKG == "false"')
        self.assertIn({'reference': ['.gated_by_build_img_container', 'rules']}, config['deploy_branches_pulp']['rules'])
        # Never into the release repositories nor the debian/ and RHEL<N>/ roots.
        for rules in (config['deploy_debian_pulp']['rules'], config['.deploy_pkg_rules']['rules']):
            for rule in rules:
                condition = rule.get('if', '') if isinstance(rule, dict) else ''
                self.assertTrue(not condition or 'devel' in condition or 'maintenance' in condition or 'CI_COMMIT_TAG' in condition, condition)
                self.assertNotIn('$CI_COMMIT_REF_NAME != "devel"', condition)

    def test_files_keep_their_published_names_for_every_os(self):
        spec = importlib.util.spec_from_file_location('publish_files', ROOT/'ci/pulp/publish-files.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as folder:
            result = Path(folder)
            for n in ('8', '9'):
                (result/'centos'/n).mkdir(parents=True)
                for prefix in ('packetfence-release', 'packetfence-upgrade', 'packetfence-export'):
                    (result/'centos'/n/f'{prefix}-16.0.0-1.el{n}.noarch.rpm').write_text('x')
                (result/'centos'/n/'packetfence-16.0.0-1.el8.src.rpm').write_text('x')
            (result/'debian'/'bookworm').mkdir(parents=True)
            for prefix in ('packetfence-upgrade', 'packetfence-export', 'packetfence-ci-lib'):
                (result/'debian'/'bookworm'/f'{prefix}_16.0.0_all.deb').write_text('x')
            planned = {(snapshot, name) for snapshot, _, name in module.plan(result, '16.0', {})}
            self.assertEqual(planned, {
                ('rhel8', 'packetfence-release-16.0.el8.noarch.rpm'), ('rhel8', 'packetfence-upgrade-16.0.el8.noarch.rpm'),
                ('rhel8', 'packetfence-export-16.0.el8.noarch.rpm'), ('rhel9', 'packetfence-release-16.0.el9.noarch.rpm'),
                ('rhel9', 'packetfence-upgrade-16.0.el9.noarch.rpm'), ('rhel9', 'packetfence-export-16.0.el9.noarch.rpm'),
                ('debian', 'packetfence-upgrade_16.0.deb'), ('debian', 'packetfence-export_16.0.deb'),
                ('debian', 'packetfence-ci-lib_16.0.deb')})
            # Architecture: all, no dependencies: a second Debian release adds no second copy.
            (result/'debian'/'trixie').mkdir()
            for prefix in ('packetfence-upgrade', 'packetfence-export', 'packetfence-ci-lib'):
                (result/'debian'/'trixie'/f'{prefix}_16.0.0_all.deb').write_text('x')
            debs = [(name, source.parent.name) for snapshot, source, name in module.plan(result, '16.0', {}) if snapshot == 'debian']
            self.assertEqual(sorted(debs), [('packetfence-ci-lib_16.0.deb', 'bookworm'), ('packetfence-export_16.0.deb', 'bookworm'),
                                            ('packetfence-upgrade_16.0.deb', 'bookworm')])
            shutil.rmtree(result/'debian'/'trixie')
            shutil.rmtree(result/'centos'/'9')
            named = {name for _, _, name in module.plan(result, '16.0', {'PF_CI_LIB_DEB_DEST_NAME': 'packetfence-ci-lib_devel.deb'})}
            self.assertIn('packetfence-ci-lib_devel.deb', named)
            # A feature branch stages them, under their branches names, for its branches/X.Y/<pipeline>/ folder.
            config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
            stage = Path(folder)/'stage'
            with mock.patch.dict(os.environ, config['deploy_branches_pulp']['variables']):
                module.main(['--release', '16.0', '--result', str(result), '--stage', str(stage)])
            self.assertEqual(sorted(str(p.relative_to(stage)) for p in stage.rglob('*.*')), [
                'debian/packetfence-ci-lib_branches.deb', 'debian/packetfence-export_branches.deb',
                'debian/packetfence-upgrade_branches.deb', 'rhel8/packetfence-export-branches.el8.noarch.rpm',
                'rhel8/packetfence-release-branches.el8.noarch.rpm', 'rhel8/packetfence-upgrade-branches.el8.noarch.rpm'])
            # No feature branch file lands in the debian/ and RHEL<N>/ roots any more.
            for rule in config['.deploy_pkg_rules']['rules']:
                self.assertNotIn('$CI_COMMIT_REF_NAME != "devel"', rule.get('if', ''))

    def test_published_files_join_the_listing(self):
        spec = importlib.util.spec_from_file_location('publish_files', ROOT/'ci/pulp/publish-files.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        labels = {'akainverse_client_path': '/downloads/PacketFence/debian/',
                  'akainverse_index_files': '["a.deb"]', 'akainverse_index_file_sizes': '{"a.deb":1}',
                  'akainverse_index_file_modified': '{"a.deb":"2026-01-01T00:00:00Z"}'}
        updated = module.listing_labels(labels, {'packetfence-ci-lib_devel.deb': 5, 'a.deb': 2}, '2026-11-16T00:00:00Z')
        self.assertEqual(json.loads(updated['akainverse_index_files']), ['a.deb', 'packetfence-ci-lib_devel.deb'])
        self.assertEqual(json.loads(updated['akainverse_index_file_sizes']), {'a.deb': 2, 'packetfence-ci-lib_devel.deb': 5})
        self.assertEqual(updated['akainverse_client_path'], '/downloads/PacketFence/debian/')

    def test_a_release_tag_stops_unless_pulp_is_ready(self):
        spec = importlib.util.spec_from_file_location('check_release', ROOT/'ci/pulp/check-release.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(module.expected('RHEL-8 Debian-12 Debian-13 RHEL-9'), {
            ('rpm', '8'), ('rpm', '9'), ('deb', 'bookworm'), ('deb', 'trixie'), ('file', 'debian'), ('file', 'rhel8'), ('file', 'rhel9')})
        with self.assertRaises(ValueError):
            module.expected('Ubuntu-24')

        class FakePulp:
            def __init__(self, repos):
                self.repos = repos
            def request(self, method, href, params):
                if 'name' in params:
                    return {'results': [{'name': params['name']}] if params['name'] in self.repos else []}
                kind = href.split('/')[-3]
                wanted = dict(pair.split('=') for pair in params.get('pulp_label_select', '').split(',') if pair)
                return {'results': [r for r in self.repos.values() if r.get('kind') == kind and all(
                    r['pulp_labels'].get(k) == v for k, v in wanted.items() if k == 'akainverse_release')]}
        def repo(name, kind, distribution='', extra=''):
            release = '.'.join(name.split('-')[1:3])
            return {'name': name, 'kind': kind, 'pulp_labels': {'akainverse_distribution': distribution, 'akainverse_release': release,
                                                                 'akainverse_extra_distributions': extra}}
        ready = {'packetfence-16-0-el8': repo('packetfence-16-0-el8', 'rpm'),
                 'packetfence-16-0-bookworm': repo('packetfence-16-0-bookworm', 'deb', 'bookworm', 'trixie'),
                 'debian': {'name': 'debian'}, 'rhel8': {'name': 'rhel8'}}
        self.assertEqual(module.problems(FakePulp(ready), '16.0', module.expected('RHEL-8 Debian-12 Debian-13')), [])
        missing = {k: v for k, v in ready.items() if k != 'packetfence-16-0-el8'}
        self.assertEqual(module.problems(FakePulp(missing), '16.0', module.expected('RHEL-8')),
                         ['EL8: no active public 16.0 repository (or not granted to ci-packages yet)'])
        no_trixie = {**ready, 'packetfence-16-0-bookworm': repo('packetfence-16-0-bookworm', 'deb', 'bookworm')}
        self.assertEqual(module.problems(FakePulp(no_trixie), '16.0', module.expected('Debian-13')),
                         ['Debian suite trixie: no active public 16.0 repository (or not granted to ci-packages yet)'])
        # The devel the release seeded must carry every package name X.Y serves, per OS.
        seeded = {**ready, 'packetfence-16-1-el8': repo('packetfence-16-1-el8', 'rpm'),
                  'packetfence-16-1-bookworm': repo('packetfence-16-1-bookworm', 'deb', 'bookworm')}
        names = {'packetfence-16-0-el8': {'packetfence', 'freeradius', 'redis'}, 'packetfence-16-1-el8': {'packetfence', 'freeradius'},
                 'packetfence-16-0-bookworm': {'packetfence', 'haproxy'}, 'packetfence-16-1-bookworm': {'packetfence', 'haproxy', 'new'}}
        lookup = lambda client, kind, name: names[name]  # noqa: E731
        self.assertEqual((module.devel_after(FakePulp(seeded), '16.0'), module.devel_after(FakePulp(ready), '16.0')), ('16.1', None))
        self.assertEqual(module.missing_in_devel(FakePulp(seeded), '16.0', module.expected('RHEL-8 Debian-12'), devel='16.1', names=lookup),
                         ['EL8: 16.1 lacks 1 package(s) of 16.0: redis'])
        self.assertEqual(module.missing_in_devel(FakePulp(seeded), '16.0', module.expected('Debian-12'), devel='16.1', names=lookup), [])
        self.assertEqual(module.missing_in_devel(FakePulp(ready), '16.0', module.expected('RHEL-8'), devel='16.1', names=lookup),
                         ['EL8: no active public 16.1 repository'])
        # Devel guard: conf/pf-release must still be Pulp's newest release.
        with tempfile.TemporaryDirectory() as folder, mock.patch.dict(os.environ, PULP_URL='https://p', PULP_USERNAME='u', PULP_PASSWORD='p'):
            release = Path(folder)/'pf-release'
            release.write_text('PacketFence 16.0.0\n')
            for pulp, stops in ((seeded, True), (ready, False)):
                with mock.patch.object(module, 'Pulp', lambda *a, pulp=pulp: FakePulp(pulp)):
                    if stops:
                        with self.assertRaises(SystemExit) as stop:
                            module.main(['--devel', '--pf-release', str(release)])
                        self.assertIn('Bump conf/pf-release on devel to 16.1', str(stop.exception))
                    else:
                        module.main(['--devel', '--pf-release', str(release)])
        with tempfile.TemporaryDirectory() as folder:
            release = Path(folder)/'pf-release'
            release.write_text('PacketFence 16.0.1\n')
            with self.assertRaises(SystemExit) as stop:
                module.main(['--tag', 'v16.0.0', '--pf-release', str(release), '--os-list', 'RHEL-8'])
            self.assertIn('does not match', str(stop.exception))

    def test_the_release_check_runs_first_on_tags(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        job = config['check_pulp_release']
        self.assertEqual(job['rules'], [{'if': '$CI_COMMIT_TAG'},
                                        {'if': '$CI_COMMIT_REF_NAME == "devel" && $DEPLOY_PKG != "no" && $DEPLOY_PKG != "false"'}])
        self.assertIn('.check_job', job['extends'])
        self.assertIn({'job': 'check_pulp_release', 'optional': True}, config['.needs_all_build_images']['needs'])

    def test_container_push_refuses_other_tags(self):
        env = dict(os.environ, **PSONO_ENV, CI_COMMIT_BRANCH='devel', CI_PIPELINE_SOURCE='web',
                   CI_COMMIT_REF_PROTECTED='true', CI_COMMIT_TAG='')
        for tags in ('v16.0.0', 'devel,feature-x', 'maintenance-15', 'devel-p7'):
            result = subprocess.run(['bash', str(ROOT/'ci/pulp/container-push.sh'), 'p-7', tags],
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, tags)
            self.assertIn('Refusing tag', result.stderr)
        feature = dict(env, CI_COMMIT_BRANCH='feature/x', CI_COMMIT_REF_SLUG='feature-x', CI_PIPELINE_ID='7',
                       CI_COMMIT_REF_PROTECTED='false')
        for source, tags in (('feature-x-p7', 'feature-x'), ('feature-x-p7', 'latest'), ('feature-x-p7', 'feature-x-p7,devel'),
                             ('feature-x-p6', 'feature-x-p6'), ('devel-p7', 'devel')):
            result = subprocess.run(['bash', str(ROOT/'ci/pulp/container-push.sh'), source, tags],
                                    env=feature, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, (source, tags))

    def test_container_push_feature_branch_pushes_only_its_pipeline_tag(self):
        with tempfile.TemporaryDirectory() as folder:
            work = Path(folder)
            fake = work/'skopeo'
            fake.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_CALLS"\n'
                            'case "$*" in "inspect "*) case "$*" in *pfcmd:feature-x-p7*|*radiusd:feature-x-p7*) exit 0;; '
                            '*) echo "manifest unknown" >&2; exit 1;; esac;; "login "*) python3 -c \'import json, sys; json.load(open(sys.argv[1]))\' "$3" || exit 1; cat > /dev/null;; esac\n')
            fake.chmod(0o700)
            script, calls = push_tree(work), work/'calls'
            calls.write_text('')
            env = dict(os.environ, **PSONO_ENV, PATH=str(work)+os.pathsep+os.environ['PATH'], TEST_CALLS=str(calls),
                       TEST_PSONO=str(work/'psono'), CI_COMMIT_BRANCH='feature/x', CI_COMMIT_REF_SLUG='feature-x',
                       CI_PIPELINE_ID='7', CI_PIPELINE_SOURCE='web', CI_COMMIT_REF_PROTECTED='false', CI_COMMIT_TAG='')
            result = subprocess.run(['bash', str(script), 'feature-x-p7', 'feature-x-p7'], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            copies = [row for row in calls.read_text().splitlines() if row.startswith('copy ')]
            self.assertEqual(len(copies), 2)  # pfcmd, radiusd
            self.assertIn('docker://ghcr.io/inverse-inc/packetfence/pfcmd:feature-x-p7 '
                          'docker://registry.example/inverse-inc/packetfence/pfcmd:feature-x-p7', copies[0])
            calls.write_text('')
            refused = subprocess.run(['bash', str(script), 'feature-x-p7', 'feature-x-p7'],
                                     env=dict(env, PSONO_CI_PULP_DOCKER_ID=''), capture_output=True, text=True)
            self.assertIn('not protected (feature branches publish too)', refused.stderr)
            self.assertEqual(calls.read_text(), '')
            for source in ('push', 'merge_request_event'):
                calls.write_text('')
                result = subprocess.run(['bash', str(script), 'feature-x-p7', 'feature-x-p7'],
                                        env=dict(env, CI_PIPELINE_SOURCE=source), capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0, source)
                self.assertEqual(calls.read_text(), '')

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

    def test_docs_are_published_after_the_tests_on_release_tags_and_maintenance_docs_builds(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        job = config['deploy_docs_pulp']
        self.assertEqual(job['stage'], 'deploy')  # after every test stage
        self.assertEqual(job['dependencies'], ['build_artifacts_doc'])
        self.assertEqual(job['script'], ['bash ci/pulp/publish-docs.sh'])
        self.assertEqual(job['artifacts']['access'], 'developer')
        rules = job['rules']
        self.assertEqual(rules[0]['if'], '$CI_COMMIT_TAG =~ /^v[0-9]+\\.[0-9]+\\.[0-9]+$/')
        self.assertEqual(rules[1], {'if': '$CI_COMMIT_TAG', 'when': 'never'})
        self.assertEqual(rules[2], {'reference': ['.gated_by_build_artifacts_doc', 'rules']})
        self.assertIn('^maintenance', rules[3]['if'])
        self.assertFalse([r for r in rules if 'devel' in r.get('if', '')])  # a devel version has no doc
        self.assertIn('PSONO_CI_PULP_DOCS_ID', config['variables'])
        script = (ROOT/'ci/pulp/publish-docs.sh').read_text()
        self.assertIn('publish-docs --repository "doc-${release/./-}-0"', script)
        self.assertIn('sha256sum --check --quiet SHA256SUMS', script)

    def test_vendored_helpers_match_recorded_checksums(self):
        vendor = ROOT/'ci/pulp/vendor'
        for line in (vendor/'SHA256SUMS').read_text().splitlines():
            sha, filename = line.split()
            self.assertEqual(hashlib.sha256((vendor/filename).read_bytes()).hexdigest(), sha)

    def test_ci_lib_package_chmods_match_files(self):
        # debuild stops on a chmod glob that matches nothing, e.g. after a ci/lib script is removed.
        globs = [line.split('$(PREFIX)/$(NAME)/', 1)[1].strip()
                 for line in (ROOT/'debian/rules').read_text().splitlines()
                 if 'chmod' in line and 'packetfence-ci-lib' in line]
        self.assertTrue(globs)
        for pattern in globs:
            self.assertTrue(list(ROOT.glob(pattern)), f'debian/rules: chmod {pattern} matches no file')

    def test_a_feature_branch_keeps_its_pipeline_ppa_in_branches(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)/'repo'
            (root/'ci/pulp/vendor').mkdir(parents=True)
            (root/'conf').mkdir()
            (root/'conf/pf-release').write_text('PacketFence 16.0.0\n')
            for name in ('publish-packages.sh', 'publish-files.py', 'psono-field.sh'):
                shutil.copy(ROOT/'ci/pulp'/name, root/'ci/pulp'/name)
            shutil.copy(ROOT/'ci/pulp/vendor/pulp_publish.py', root/'ci/pulp/vendor/pulp_publish.py')
            # The Pulp helper records each publish: its arguments and the tree it would upload.
            (root/'ci/pulp/vendor/pipeline_repository.py').write_text(
                'import json, os, sys\nfrom pathlib import Path\n'
                'args = sys.argv[1:]; tree = Path(args[args.index("--tree") + 1])\n'
                'files = sorted(str(p.relative_to(tree)) for p in tree.rglob("*") if p.is_file())\n'
                'with open(os.environ["TEST_CALLS"], "a") as out:\n'
                '    out.write(json.dumps({"args": args, "files": files, '
                '"marker": json.loads((tree/"pipeline.json").read_text())}) + "\\n")\n')
            vendor = root/'ci/pulp/vendor'
            (vendor/'SHA256SUMS').write_text(''.join(f'{hashlib.sha256((vendor/n).read_bytes()).hexdigest()}  {n}\n'
                                                     for n in ('pulp_publish.py', 'pipeline_repository.py')))
            (root/'addons/packetfence-perl').mkdir(parents=True)
            (root/'addons/packetfence-perl/psono.py').write_text(
                'print(\'{"website_password_username": "ci-packages", "website_password_password": "secret"}\')\n')
            public, result = root/'public', root/'result'
            for path in ('GPG_PUBLIC_KEY', 'debian/dists/bookworm/InRelease', 'debian/pool/main/p/packetfence_16.0.0_all.deb',
                         'centos/8/x86_64/repodata/repomd.xml', 'centos/8/x86_64/RPMS/packetfence-16.0.0.el8.noarch.rpm',
                         'centos/8/x86_64/RPMS/packetfence-release-2.4.1.el8.noarch.rpm'):
                (public/path).parent.mkdir(parents=True, exist_ok=True)
                (public/path).write_text('x')
            for path in ('centos/8/packetfence-release-2.4.1.el8.noarch.rpm', 'centos/8/packetfence-upgrade-16.0.0.el8.noarch.rpm',
                         'centos/8/packetfence-export-16.0.0.el8.noarch.rpm', 'debian/bookworm/packetfence-upgrade_16.0.0_all.deb',
                         'debian/bookworm/packetfence-export_16.0.0_all.deb', 'debian/bookworm/packetfence-ci-lib_16.0.0_all.deb'):
                (result/path).parent.mkdir(parents=True, exist_ok=True)
                (result/path).write_text('x')
            calls = Path(folder)/'calls'
            config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
            env = dict(os.environ, **PSONO_ENV, **config['deploy_branches_pulp']['variables'], TEST_CALLS=str(calls),
                       PSONO_CI_PULP_PACKAGES_ID='packages-entry', CI_PIPELINE_ID='42', CI_COMMIT_REF_NAME='feature/x',
                       CI_COMMIT_REF_SLUG='feature-x', CI_COMMIT_SHA='abc')
            run = subprocess.run(['bash', str(root/'ci/pulp/publish-packages.sh'), 'branches'], cwd=root, env=env,
                                 capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            deb, rpm = [json.loads(line) for line in calls.read_text().splitlines()]
            for call, repository in ((deb, 'debian-branches-16-0'), (rpm, 'rhel8-branches-16-0')):
                self.assertEqual(call['args'][:5], ['publish', '--repository', repository, '--pipeline', '42'])
                self.assertIn('--no-lock', call['args'])
                self.assertEqual({k: call['marker'][k] for k in ('branch', 'slug', 'pipeline', 'release')},
                                 {'branch': 'feature/x', 'slug': 'feature-x', 'pipeline': 42, 'release': '16.0'})
            self.assertEqual(deb['files'], ['GPG_PUBLIC_KEY', 'dists/bookworm/InRelease', 'packetfence-ci-lib_branches.deb',
                                            'packetfence-export_branches.deb', 'packetfence-upgrade_branches.deb',
                                            'pipeline.json', 'pool/main/p/packetfence_16.0.0_all.deb'])
            self.assertEqual(rpm['files'], ['GPG_PUBLIC_KEY', 'packetfence-export-branches.el8.noarch.rpm',
                                            'packetfence-release-branches.el8.noarch.rpm',
                                            'packetfence-upgrade-branches.el8.noarch.rpm', 'pipeline.json',
                                            'x86_64/RPMS/packetfence-16.0.0.el8.noarch.rpm',
                                            'x86_64/RPMS/packetfence-release-2.4.1.el8.noarch.rpm', 'x86_64/repodata/repomd.xml'])
            self.assertIn('debian/branches/16.0/42/', run.stdout)
            # An empty Pulp variable is named, with how to set it.
            calls.write_text('')
            refused = subprocess.run(['bash', str(root/'ci/pulp/publish-packages.sh'), 'branches'], cwd=root, capture_output=True,
                                     text=True, env=dict(env, PSONO_CI_PULP_PACKAGES_ID=''))
            self.assertNotEqual(refused.returncode, 0)
            self.assertIn('not protected (feature branches publish too)', refused.stderr)
            self.assertEqual(calls.read_text(), '')

    def test_a_branch_deploy_without_pulp_credentials_says_why_before_the_key_import(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        script = '\n'.join(config['deploy_branches_pulp']['before_script'])
        with tempfile.TemporaryDirectory() as folder:
            work = Path(folder)
            (work/'addons/packetfence-perl').mkdir(parents=True)
            (work/'addons/packetfence-perl/psono.py').write_text('print("key")\n')
            (work/'gpg').write_text('#!/bin/sh\necho imported >> "$TEST_CALLS"\ncat > /dev/null\n')
            (work/'gpg').chmod(0o700)
            calls = work/'calls'
            full = {'PATH': str(work) + os.pathsep + os.environ['PATH'], 'TEST_CALLS': str(calls),
                    'PSONO_CI_API_KEY_ID': 'k', 'PSONO_CI_API_SECRET_KEY_HEX': 's', 'PSONO_GPG_PRIVATE_KEY_SECRET_ID': 'g',
                    'PSONO_CI_PULP_PACKAGES_ID': 'p'}
            for empty in ('PSONO_CI_API_KEY_ID', 'PSONO_GPG_PRIVATE_KEY_SECRET_ID', 'PSONO_CI_PULP_PACKAGES_ID'):
                result = subprocess.run(['bash', '-c', script], cwd=work, env={**full, empty: ''}, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0, empty)
                self.assertIn(empty + ' is empty', result.stderr)
                self.assertIn('not protected (feature branches publish too)', result.stderr)
                self.assertFalse(calls.exists(), empty)
            result = subprocess.run(['bash', '-c', script], cwd=work, env=full, capture_output=True, text=True)
            self.assertEqual((result.returncode, calls.read_text()), (0, 'imported\n'), result.stderr)

    def test_only_a_feature_build_ships_the_packetfence_branches_repository(self):
        # The Makefile names the pipeline only when CI sets it (feature branches, .context_rules), and the spec
        # writes [packetfence-branches] only then, pointing at that pipeline's folder (extra_vars_branches.yml).
        makefile = (ROOT/'Makefile').read_text()
        self.assertIn('$(if $(PF_BRANCHES_PIPELINE),echo "%pf_branches_pipeline $(PF_BRANCHES_PIPELINE)"', makefile)
        self.assertNotIn('pf_branches_dir', makefile)
        spec = (ROOT/'rpm/packetfence-release.spec').read_text()
        stanza = spec[spec.index('%if 0%{?pf_branches_pipeline:1}'):]
        stanza = stanza[:stanza.index('%endif')]
        self.assertIn('[packetfence-branches]', stanza)
        self.assertIn('/branches/%{pf_minor_release}/%{pf_branches_pipeline}/\\$basearch', stanza)
        # Served by the package origin CI publishes to (Pulp), not inverse.ca (no branches/X.Y/<pipeline>/ there).
        self.assertIn('baseurl=%{pf_package_origin}/downloads/PacketFence/RHEL', stanza)
        self.assertIn('%{!?pf_package_origin:%global pf_package_origin https://packages.packetfence.com}', spec)
        self.assertIn('$(if $(PF_PACKAGE_ORIGIN),echo "%pf_package_origin $(PF_PACKAGE_ORIGIN)"', makefile)
        self.assertEqual(spec.count('[packetfence-branches]'), 1)
        # Every repository of packetfence-release on the origin CI publishes to, none on inverse.ca.
        self.assertEqual(spec.count('baseurl=%{pf_package_origin}/downloads/PacketFence/RHEL'), 3)
        self.assertNotIn('inverse.ca/downloads', spec)
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        branches = [r for r in config['.context_rules']['rules'] if r.get('variables', {}).get('CONTEXT') == 'branches']
        self.assertEqual([r['variables']['PF_BRANCHES_PIPELINE'] for r in branches], ['$CI_PIPELINE_ID'])
        self.assertFalse([r for r in config['.context_rules']['rules']
                          if r.get('variables', {}).get('CONTEXT') != 'branches' and 'PF_BRANCHES_PIPELINE' in r.get('variables', {})])
        if shutil.which('make'):
            for pipeline, wanted in (('42', '%pf_branches_pipeline 42'), ('', None)):
                dry = subprocess.run(['make', '-s', '-n', '-C', str(ROOT), 'rpm/.rpmmacros'] +
                                     ([f'PF_BRANCHES_PIPELINE={pipeline}'] if pipeline else []), capture_output=True, text=True)
                lines = [l for l in dry.stdout.splitlines() if 'pf_branches' in l]
                self.assertEqual([wanted in l for l in lines] if wanted else lines, [True] if wanted else [])

    def test_zen_is_built_from_the_deployed_repository(self):
        # Zen installs what users install: debian/X.Y, or a feature branch's deployed branches/X.Y/<pipeline>/.
        zen = ROOT/'ci/zen'
        requirements = yaml.safe_load((zen/'packer/provisioners/requirements.yml').read_text())
        version = [c['version'] for c in requirements['collections'] if c['name'] == 'inverse_inc.packetfence']
        self.assertEqual(version, ['1.3.0'])  # first release with packetfence_install__package_origin
        inventory = (zen/'packer/provisioners/inventory/group_vars/pfservers/packetfence_install.yml').read_text()
        self.assertIn('packetfence_install__package_origin: \'{{ lookup("env", "PF_PACKAGE_ORIGIN")', inventory)
        self.assertNotIn('https://', inventory.replace('default("https://packages.packetfence.com"', ''))
        for name in ('PF_PACKAGE_ORIGIN', 'PF_BRANCHES_PIPELINE'):
            self.assertIn(f'"{name}=${{var.{name.lower()}}}"', (zen/'packer/build.pkr.hcl').read_text())
            self.assertIn(f'-e PKR_VAR_{name.lower()} \\', (zen/'zen-in-docker.sh').read_text())
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        arms = [r.get('variables', {}).get('PF_BRANCHES_PIPELINE') for r in config['build_pf_img_zen']['rules']]
        self.assertEqual(arms, [None, None, None, '$CI_PIPELINE_ID'])  # tag, devel, maintenance, feature
        if shutil.which('make'):
            for pipeline in ('', '42'):
                dry = subprocess.run(['make', '-n', '-C', str(zen), 'zen-deb12', 'PF_MINOR_RELEASE=15.2',
                                      f'PF_BRANCHES_PIPELINE={pipeline}'], capture_output=True, text=True)
                self.assertIn(f'PF_BRANCHES_PIPELINE="{pipeline}"', dry.stdout)
                self.assertIn('../lib/common/deployed-repo.sh --check 15.2', dry.stdout)
                self.assertIn(f'PKR_VAR_pf_branches_pipeline="{pipeline}"', dry.stdout)

    def deployed_repo(self, *args, pipeline='', origin='', published=True):
        with tempfile.TemporaryDirectory() as tmp:
            curl = Path(tmp)/'curl'
            curl.write_text('#!/bin/sh\necho "$@" >> "%s/calls"\nexit %d\n' % (tmp, 0 if published else 22))
            curl.chmod(0o755)
            env = dict(os.environ, PATH=f'{tmp}:{os.environ["PATH"]}', PF_BRANCHES_PIPELINE=pipeline, PF_PACKAGE_ORIGIN=origin)
            run = subprocess.run([str(ROOT/'ci/lib/common/deployed-repo.sh'), *args], env=env, capture_output=True, text=True)
            calls = (Path(tmp)/'calls').read_text() if (Path(tmp)/'calls').exists() else ''
        return run, calls

    def test_deployed_repo_names_what_users_install(self):
        base = 'https://packages.packetfence.com/downloads/PacketFence/debian/'
        run, calls = self.deployed_repo('16.0')
        self.assertEqual((run.returncode, run.stdout, calls), (0, f'{base}16.0 bookworm bookworm\n', ''))
        run, _ = self.deployed_repo('16.0', pipeline='42', origin='https://staging.example')
        self.assertEqual(run.stdout, 'https://staging.example/downloads/PacketFence/debian/branches/16.0/42 bookworm main\n'
                                     'https://staging.example/downloads/PacketFence/debian/16.0 bookworm bookworm\n')
        run, calls = self.deployed_repo('--check', '16.0', pipeline='42')
        self.assertEqual(run.returncode, 0)
        self.assertIn(f'{base}branches/16.0/42/dists/bookworm/InRelease', calls)
        run, _ = self.deployed_repo('--check', '16.0', pipeline='42', published=False)
        self.assertEqual((run.returncode, run.stdout), (1, ''))
        self.assertIn(f'{base}branches/16.0/42 is not deployed', run.stderr)
        self.assertIn('DEPLOY_PKG=yes', run.stderr)

    def test_isos_are_built_from_the_deployed_repository(self):
        # Both ISOs install what users install and wait for the deploys by stage order; no inverse.ca, no gitlab/ PPA.
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        for job, arms in (('build_pf_img_dvd_usb_iso', [None, '$CI_PIPELINE_ID']),
                          ('build_pf_img_cd_iso', [None, None, None, '$CI_PIPELINE_ID'])):
            self.assertNotIn('needs', config[job])
            self.assertNotIn('PF_REPO_TYPE', config[job].get('variables', {}))
            self.assertEqual([r.get('variables', {}).get('PF_BRANCHES_PIPELINE') for r in config[job]['rules']], arms)
        self.assertFalse([r for r in config['.gated_by_publish_ppa']['rules'] if 'dvd_usb_iso' in r['if'].lower()])
        for path in ('ci/dvd-usb-iso/create-local-repo.sh', 'ci/dvd-usb-iso/build-usb-bootable-iso.sh', 'ci/cd-iso/build-and-upload.sh'):
            self.assertIn('lib/common/deployed-repo.sh" --check' if 'dvd' in path else 'lib/common/deployed-repo.sh --check',
                          (ROOT/path).read_text())
        self.assertIn('-e PF_PACKAGE_ORIGIN \\', (ROOT/'ci/dvd-usb-iso/step2-create-local-repo.sh').read_text())
        self.assertIn('-e PF_BRANCHES_PIPELINE \\', (ROOT/'ci/dvd-usb-iso/step2-create-local-repo.sh').read_text())
        self.assertIn('-e PF_APT_SOURCES -e PF_KEY_URL', (ROOT/'ci/cd-iso/build-and-upload.sh').read_text())
        for path in ('ci/dvd-usb-iso', 'ci/cd-iso'):
            for script in (ROOT/path).iterdir():
                if script.is_file():
                    self.assertNotIn('inverse.ca/downloads', script.read_text(), script)
                    self.assertNotIn('debian-branches', script.read_text(), script)

    def test_requested_tests_build_images_and_packages_but_publish_nothing(self):
        text = (ROOT/'.gitlab-ci.yml').read_text()
        config = yaml.load(text, Loader=GitLabLoader)
        # The deploys' gates never let tests through: BUILD_IMG_CONTAINER=no or BUILD_ARTIFACTS_PKG=no publishes nothing.
        deploys = [n for n in config if n.startswith('deploy_') and not n.startswith('deploy_docs')]
        deploy_gate = {r['if'] for n in deploys for r in resolved_rules(config, n) if 'if' in r}
        builds = [line.split("if: '", 1)[1].rstrip("'") for line in text.splitlines()
                  if re.match(r"\s*- if: '\$(BUILD_IMG_CONTAINER == \"no\"|CI_COMMIT_MESSAGE =~ /build_img_container=no/|BUILD_ARTIFACTS_PKG == \"no\")", line)]
        self.assertTrue(builds)
        for condition in builds:
            if condition in deploy_gate:
                self.assertNotIn('TEST', condition)
            else:  # a build: tests requested build this pipeline's images and packages
                self.assertIn('$TEST != "yes"', condition)
                self.assertIn('$CI_COMMIT_MESSAGE !~ /test=yes/', condition)
                if '$TEST_ONLY != ""' in text:
                    self.assertIn('$TEST_ONLY == ""', condition)
        for name in ('deploy_branches_pulp', 'deploy_containers'):
            for rule in config[name].get('rules', []):
                if 'BUILD_IMG_CONTAINER' in rule.get('if', ''):
                    self.assertNotIn('TEST', rule['if'], name)
        gate = {'if': '$BUILD_ARTIFACTS_PKG == "no"', 'when': 'never'}
        for name in deploys:
            rules = resolved_rules(config, name)
            self.assertIn(gate, rules, name)
            self.assertTrue(all(r.get('when') == 'never' for r in rules[:rules.index(gate)]), name)
            images = [r for r in rules if r.get('when') == 'never' and 'BUILD_IMG_CONTAINER == "no"' in r['if']]
            self.assertTrue(images and all('TEST' not in r['if'] for r in images), name)
        # The published file names point at this build's packages: never before (or without) them.
        files, packages = (('deploy_files_pulp', 'deploy_debian_pulp') if 'deploy_files_pulp' in config
                           else ('deploy_maintenance_pkg_friendly_names', 'deploy_maintenance_pulp'))
        self.assertIn({'job': packages, 'artifacts': False}, config[files]['needs'])
        helper = ROOT/'ci/lib/common/pipeline-image-tag.sh'
        base = {'PATH': os.environ['PATH'], 'CI_PIPELINE_ID': '42', 'CI_COMMIT_REF_NAME': 'feature/x',
                'CI_COMMIT_REF_SLUG': 'feature-x', 'CI_PIPELINE_SOURCE': 'web'}
        for env, expected in (({'BUILD_IMG_CONTAINER': 'no'}, ''), ({'BUILD_IMG_CONTAINER': 'no', 'TEST': 'yes'}, 'feature-x-p42'),
                              ({'CI_COMMIT_MESSAGE': 'fix\n\nbuild_img_container=no test=yes'}, 'feature-x-p42')):
            result = subprocess.run(['sh', str(helper)], env={**base, **env}, capture_output=True, text=True)
            self.assertEqual(result.stdout.strip(), expected, env)

    def test_container_push_fails_on_unexpected_registry_errors(self):
        # Only a missing tag or a private image is skipped; a GHCR error or a missing core image fails the push.
        with tempfile.TemporaryDirectory() as folder:
            work = Path(folder)
            script = push_tree(work)
            for broken, message in (('*pfcron:*) echo "received unexpected HTTP status: 503" >&2; exit 1;;',
                                     'pfcron: cannot read'),
                                    ('*radiusd:*) echo "manifest unknown" >&2; exit 1;;', 'radiusd lacks the pipeline tag')):
                with self.subTest(message=message):
                    fake = work/'skopeo'
                    fake.write_text('#!/bin/sh\ncase "$*" in "inspect "*) case "$*" in ' + broken + ' '
                                    '*pfcmd:p-7*|*radiusd:p-7*) exit 0;; *) echo "manifest unknown" >&2; exit 1;; esac;; '
                                    '"login "*) cat > /dev/null;; "copy "*) echo "$*" >> ' + str(work/'copies') + ';; esac\n')
                    fake.chmod(0o700)
                    env = dict(os.environ, **PSONO_ENV, PATH=str(work)+os.pathsep+os.environ['PATH'],
                               TEST_PSONO=str(work/'psono'), CI_COMMIT_BRANCH='devel', CI_PIPELINE_SOURCE='web',
                               CI_COMMIT_REF_PROTECTED='true', CI_COMMIT_TAG='')
                    result = subprocess.run(['bash', str(script), 'p-7', 'devel,latest'], env=env,
                                            capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(message, result.stderr)
                    self.assertFalse((work/'copies').exists(), 'nothing is pushed before every image is checked')

    def test_a_release_publish_requires_every_native_el_repository(self):
        script = (ROOT/'ci/pulp/publish-packages.sh').read_text()
        block = script[script.index('native_rpm=$(python3 ci/pulp/native.py rpm'):]
        block = block[:block.index('\ndone\n')]
        self.assertIn('if [[ "${CI_COMMIT_REF_NAME:-}" != devel ]]; then', block)
        self.assertLess(block.index('exit 1'), block.index('continue'))

    def test_every_ansible_requirement_installs_from_the_package_origin(self):
        # inverse_inc.packetfence before 1.3.0 hard-codes inverse.ca in its repository line.
        pins = {}
        for path in ROOT.glob('**/requirements.yml'):
            data = yaml.safe_load(path.read_text()) or {}
            for item in data.get('collections', []) if isinstance(data, dict) else []:
                if isinstance(item, dict) and item.get('name') == 'inverse_inc.packetfence':
                    pins[str(path.relative_to(ROOT))] = str(item.get('version'))
        self.assertTrue(pins)
        for path, version in pins.items():
            self.assertGreaterEqual(tuple(int(x) for x in version.split('.')), (1, 3, 0), path)

    def test_a_pulp_error_is_not_a_missing_native_repository(self):
        # Unreachable Pulp: exit 2, which every caller turns into a failure (never the devel skip or the file tree).
        env = {'PATH': os.environ['PATH'], 'PULP_URL': 'http://127.0.0.1:9', 'PULP_USERNAME': 'u', 'PULP_PASSWORD': 'p'}
        result = subprocess.run([sys.executable, str(ROOT/'ci/pulp/native.py'), 'deb', '14.0', 'bookworm'],
                                env=env, capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertNotIn('p@', result.stderr)
        script = (ROOT/'ci/pulp/publish-packages.sh').read_text()
        self.assertEqual(script.count('python3 ci/pulp/native.py'), 2)
        self.assertEqual(script.count('(( status < 2 )) || exit 1'), 2)

    def test_shell_syntax(self):
        for script in (ROOT/'ci/pulp').rglob('*.sh'):
            subprocess.run(['bash', '-n', str(script)], check=True)
        subprocess.run(['bash', '-n', str(ROOT/'ci/scripts/generate-pages.sh')], check=True)
        subprocess.run(['bash', '-n', str(ROOT/'ci/dvd-usb-iso/create-local-repo.sh')], check=True)

if __name__ == '__main__':
    unittest.main()
