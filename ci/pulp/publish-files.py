#!/usr/bin/env python3
"""Publish packetfence-release/-export/-upgrade/-ci-lib into the debian/ and RHEL<N>/ file snapshots.

Published names follow the context (devel, maintenance, release, branches) through the *_DEST_NAME
variables .deploy_pkg_rules sets, which may carry a {release} (and {n}, the EL version, for an RPM)
placeholder: RPMs from result/centos/<N>/ go to the rhel<N> snapshot, debs from
result/debian/<suite>/ to the debian one: they are Architecture: all with no dependencies, so one copy
serves every Debian release (the first suite built). A file already published with the same bytes is left alone;
otherwise it replaces the one at that path, the snapshot is republished and the listing labels follow.
Credentials come from PULP_URL / PULP_USERNAME / PULP_PASSWORD (ci-packages); a missing snapshot fails.
"""
import argparse
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / 'vendor'))
from pulp_publish import API, Pulp  # noqa: E402

RPM_FILES = (('packetfence-release', 'PKG_DEST_NAME', 'packetfence-release-{release}.el{n}.noarch.rpm'),
             ('packetfence-upgrade', 'PF_UPGRADE_RPM_DEST_NAME', 'packetfence-upgrade-{release}.el{n}.noarch.rpm'),
             ('packetfence-export', 'PF_EXPORT_RPM_DEST_NAME', 'packetfence-export-{release}.el{n}.noarch.rpm'))
DEB_FILES = (('packetfence-upgrade', 'PF_UPGRADE_DEB_DEST_NAME', 'packetfence-upgrade_{release}.deb'),
             ('packetfence-export', 'PF_EXPORT_DEB_DEST_NAME', 'packetfence-export_{release}.deb'),
             ('packetfence-ci-lib', 'PF_CI_LIB_DEB_DEST_NAME', 'packetfence-ci-lib_{release}.deb'))
LABEL = 'akainverse_'


def built_file(directory, prefix):
    found = sorted(p for p in directory.glob(prefix + '*') if p.is_file() and not p.name.endswith('.src.rpm'))
    if len(found) != 1:
        raise ValueError(f'Expected one {prefix}* in {directory}, found {len(found)}')
    return found[0]


def plan(result, release, environ):
    """[(snapshot, source path, published name)] for what this pipeline built."""
    out = []
    for directory in sorted((result / 'centos').glob('*')):
        if directory.is_dir() and directory.name.isdigit():
            for prefix, variable, default in RPM_FILES:
                name = (environ.get(variable) or default).format(release=release, n=directory.name)
                out.append(('rhel' + directory.name, built_file(directory, prefix), name))
    for directory in sorted((result / 'debian').glob('*')):
        if directory.is_dir():
            for prefix, variable, default in DEB_FILES:
                name = (environ.get(variable) or default).format(release=release)
                if ('debian', name) not in {(s, n) for s, _, n in out}:
                    out.append(('debian', built_file(directory, prefix), name))
    names = [(snapshot, name) for snapshot, _, name in out]
    if len(names) != len(set(names)):
        raise ValueError('Two built files would be published under the same name: ' + repr(sorted(names)))
    return out


def listing_labels(labels, files, now):
    """The distribution's index labels with these {name: size} files added or updated."""
    def load(key, empty):
        return json.loads(labels[LABEL + key]) if LABEL + key in labels else empty
    index, sizes, modified = load('index_files', []), load('index_file_sizes', {}), load('index_file_modified', {})
    for name, size in files.items():
        if name not in index:
            index.append(name)
        sizes[name], modified[name] = size, now
    dump = lambda value: json.dumps(value, sort_keys=True, separators=(',', ':'))  # noqa: E731
    return {**labels, LABEL + 'index_files': dump(sorted(index)), LABEL + 'index_file_sizes': dump(sizes),
            LABEL + 'index_file_modified': dump(modified)}


def publish(client, snapshot, items):
    repo = client.find('repositories/file/file', snapshot)
    dist = client.find('distributions/file/file', snapshot)
    entries = client.request('GET', API + 'content/file/files/',
                             params={'repository_version': repo['latest_version_href'], 'limit': 1000})['results']
    current = {entry['relative_path']: entry['sha256'] for entry in entries}
    # Behind: an earlier run uploaded files but its publication or distribution update failed.
    served = dist.get('publication')
    behind = not served or client.request('GET', served)['repository_version'] != repo['latest_version_href']
    changed = {}
    for _, path, name in items:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if current.get(name) == digest:
            print(f'{snapshot}/{name}: unchanged')
            continue
        client.upload(API + 'content/file/files/', path, {'relative_path': name, 'repository': repo['pulp_href']})
        changed[name] = path.stat().st_size
        print(f'{snapshot}/{name}: published')
    if not changed and not behind:
        return
    if behind:  # publish them now, and list every file (the earlier run listed none)
        changed = {name: path.stat().st_size for _, path, name in items}
        # Including those another context (other *_DEST_NAME) uploaded to this snapshot without publishing.
        listed = set(json.loads((dist.get('pulp_labels') or {}).get(LABEL + 'index_files', '[]')))
        for entry in entries:
            if entry['relative_path'] not in changed and entry['relative_path'] not in listed and entry.get('artifact'):
                try:  # artifacts may be admin-only: then the packaging side's listing picks the file up later
                    changed[entry['relative_path']] = client.request('GET', entry['artifact'])['size']
                except RuntimeError as error:  # an HTTP error status; a network error fails the run (retried)
                    print(f'{snapshot}/{entry["relative_path"]}: published, not listed ({error})')
    repo = client.request('GET', repo['pulp_href'])
    task = client.wait(client.request('POST', API + 'publications/file/file/',
                                      json={'repository_version': repo['latest_version_href'], 'manifest': 'PULP_MANIFEST'}))
    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    client.wait(client.request('PATCH', dist['pulp_href'], json={
        'publication': task['created_resources'][0], 'pulp_labels': listing_labels(dist.get('pulp_labels') or {}, changed, now)}))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', required=True)
    parser.add_argument('--result', type=Path, default=Path('result'))
    parser.add_argument('--stage', type=Path, help='Copy to <stage>/<snapshot>/<name> instead of publishing')
    args = parser.parse_args(argv)
    items = plan(args.result, args.release, os.environ)
    if not items:
        raise SystemExit('Nothing built to publish under ' + str(args.result))
    if args.stage:
        for snapshot, source, name in items:
            (args.stage / snapshot).mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, args.stage / snapshot / name)
        return
    client = Pulp(os.environ['PULP_URL'], os.environ['PULP_USERNAME'], os.environ['PULP_PASSWORD'])
    for snapshot in sorted({item[0] for item in items}):
        publish(client, snapshot, [item for item in items if item[0] == snapshot])


if __name__ == '__main__':
    main()
