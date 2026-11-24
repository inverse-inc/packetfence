"""Offline CI wiring checks; requires PyYAML."""
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from unittest import mock
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
    def test_container_push_runs_in_deploy_containers_with_the_packages(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        job = config['deploy_containers']
        self.assertEqual(job['resource_group'], 'pulp-packetfence-containers')
        # Images are built straight to GHCR as maintenance-X-Y; the same tag is copied, unchanged.
        self.assertEqual(job['script'], ['bash ci/pulp/container-push.sh "$CI_COMMIT_REF_SLUG" "$CI_COMMIT_REF_SLUG"'])
        self.assertEqual(job['stage'], 'deploy')
        # No needs: the deploy stage waits for the tests when a pipeline runs them.
        self.assertNotIn('needs', job)

        def gated_by(template, inline):
            refs = [r for r in job['rules'] if (r.get('reference') or [None])[0] == template]
            own = [r for r in job['rules'] if r.get('when') == 'never' and r.get('if') == inline]
            return bool(refs or own)

        # Nothing built or nothing deployed: no push. Otherwise the packages decide.
        self.assertTrue(gated_by('.gated_by_build_img_container',
                                 '$BUILD_IMG_CONTAINER == "no" || $CI_COMMIT_MESSAGE =~ /build_img_container=no/'))
        self.assertTrue(gated_by('.gated_by_deploy_pkg', '$DEPLOY_PKG == "no" || $DEPLOY_PKG == "false"'))
        arms = [r for r in job['rules'] if 'if' in r and r.get('when') != 'never']
        self.assertEqual(len(arms), 1)
        self.assertTrue(arms[0]['if'].startswith('$CI_COMMIT_REF_NAME =~ /^maintenance'))
        self.assertNotIn('$TEST', arms[0]['if'])  # published with the packages, tests or not
        self.assertIn('$CI_COMMIT_TAG == null', arms[0]['if'])
        # The same pipeline sources the package deploy accepts.
        packages = config.get('deploy_debian_pulp', {}).get('rules') or config['.deploy_maintenance_rules']['rules']
        sources = lambda text: set(re.findall(r'\$CI_PIPELINE_SOURCE == "(\w+)"', text))  # noqa: E731
        wanted = set().union(*(sources(r['if']) for r in packages if 'maintenance' in (r.get('if') or '')))
        self.assertEqual(sources(arms[0]['if']), wanted)
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

    def test_every_service_image_is_in_the_push_list(self):
        # A service image missing from container-images.json would never reach the registry.
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        listed = set(json.loads((ROOT/'ci/pulp/container-images.json').read_text())['images'])
        built = set()
        for name in ('pfdeb_br_maint', 'pfdeb_based_br_maint', 'img_br_maint', 'rad_based_br_maint', 'rad_extend_br_maint'):
            job = config[name]
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
        for gone in ('deploy_devel_deb', 'deploy_release_deb', 'deploy_maintenance_deb', 'deploy_branches_deb',
                     'deploy_maintenance_rpm', 'deploy_release_pkg_friendly_names', 'deploy_release_website_artifacts',
                     'build_artifacts_website_release', '.deploy_rpm_job', '.deploy_website_artifacts_job'):
            self.assertNotIn(gone, config)
        for word in ('PF_PULP_PUBLISH', 'deploy-artifacts.sh', 'web.inverse.ca', 'ci-pages-'):
            self.assertNotIn(word, text)
        # A release tag publishes nothing: no deploy job runs on tags.
        for name, job in config.items():
            if isinstance(job, dict) and name.startswith('deploy_'):
                self.assertNotIn('.release_only_rules', job.get('extends', []), name)
        self.assertEqual(config['.deploy_pulp_job']['script'][-1], 'bash ci/pulp/publish-packages.sh release')
        self.assertEqual(config['.deploy_pkg_friendly_names']['script'], ['bash ci/pulp/publish-packages.sh files'])
        self.assertEqual(config['deploy_maintenance_pulp']['extends'], ['.deploy_pulp_job', '.deploy_maintenance_rules'])
    def test_feature_branches_deploy_with_deploy_pkg_yes_or_true(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        rules = [r['if'] for r in config['.deploy_branches_rules']['rules'] if 'when' not in r]
        self.assertTrue(rules)
        for rule in rules:
            for wanted in ('$DEPLOY_PKG == "yes"', '$DEPLOY_PKG == "true"', '$PUBLISH_PPA == "yes"', '$PUBLISH_PPA == "true"'):
                self.assertIn(wanted, rule)
        for name in ('deploy_branches_pulp', 'deploy_branches_pkg_friendly_names'):
            self.assertIn('.deploy_branches_rules', config[name]['extends'])
        for name in ('.deploy_maintenance_rules', '.deploy_branches_rules'):
            self.assertEqual(config[name]['rules'][0]['if'], '$DEPLOY_PKG == "no" || $DEPLOY_PKG == "false"')
        # A feature branch never deploys images to the registry.
        for rule in config['deploy_containers']['rules']:
            self.assertNotIn('$CI_COMMIT_REF_NAME != "devel"', rule.get('if', ''))
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
            # The branches packetfence-release carries an X.Y-specific baseurl, so every X.Y must
            # publish its own file instead of overwriting one name shared with the other versions.
            text = (ROOT/'.gitlab-ci.yml').read_text()
            wanted = {v for v in re.findall(r'PKG_DEST_NAME: (\S+)', text) if 'branches' in v}
            self.assertTrue(wanted)
            for value in wanted:
                named = {name for _, _, name in module.plan(result, '16.0', {'PKG_DEST_NAME': value})}
                self.assertIn('packetfence-release-branches-16.0.el8.noarch.rpm', named)
            self.assertIn('packetfence-release-branches-{{ pf_minor_release }}.el8.noarch.rpm',
                          (ROOT/'addons/vagrant/extra_vars_branches.yml').read_text())

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
        self.assertEqual(job['rules'], [{'if': '$CI_COMMIT_TAG'}])  # no devel on a maintenance branch
        self.assertIn('.check_job', job['extends'])  # check stage: every later stage waits for it

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
        self.assertEqual(config['.publish_job']['artifacts']['access'], 'developer')
        self.assertNotIn('artifacts', config['deploy_containers'])  # the push leaves no plan to keep

    def test_docs_are_published_after_the_tests_on_release_tags_and_maintenance_docs_builds(self):
        config = yaml.load((ROOT/'.gitlab-ci.yml').read_text(), Loader=GitLabLoader)
        template = config['.deploy_docs_pulp_job']
        self.assertEqual(template['stage'], 'deploy')  # after every test stage
        self.assertEqual(template['script'], ['bash ci/pulp/publish-docs.sh'])
        self.assertEqual(template['artifacts']['access'], 'developer')
        release, maintenance = config['deploy_docs_pulp_release'], config['deploy_docs_pulp_maintenance']
        self.assertEqual(release['dependencies'], ['build_artifacts_doc_release'])
        self.assertEqual(release['rules'], [{'if': '$CI_COMMIT_TAG =~ /^v[0-9]+\\.[0-9]+\\.[0-9]+$/'}])
        self.assertEqual(maintenance['dependencies'], ['build_artifacts_doc_devel_and_branches'])
        # Exactly when the maintenance docs are built.
        self.assertEqual(maintenance['rules'][:1], [r for r in config['.build_artifacts_doc_devel_and_branches_rules']['rules']
                                                    if r['if'].startswith('$CI_COMMIT_REF_NAME =~ /^maintenance')])
        # TEMPORARY staging rehearsal: only on request, and never with the production origin.
        rehearsal = maintenance['rules'][1]['if']
        self.assertIn('$DEPLOY_DOCS == "yes"', rehearsal)
        self.assertIn('$PF_PACKAGE_ORIGIN == "https://packages-staging.packetfence.com"', rehearsal)  # never another host
        self.assertEqual(config['variables']['PF_PACKAGE_ORIGIN'], 'https://packages.packetfence.com')
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

    def test_shell_syntax(self):
        for script in (ROOT/'ci/pulp').rglob('*.sh'):
            subprocess.run(['bash', '-n', str(script)], check=True)
        subprocess.run(['bash', '-n', str(ROOT/'ci/scripts/generate-pages.sh')], check=True)
        subprocess.run(['bash', '-n', str(ROOT/'ci/dvd-usb-iso/create-local-repo.sh')], check=True)

if __name__ == '__main__':
    unittest.main()
