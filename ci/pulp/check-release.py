#!/usr/bin/env python3
"""Stop a release tag pipeline early when Pulp is not ready for it (check stage, before any build).

The tag must match conf/pf-release, and for X.Y every OS in OS_SUPPORTED must have an active public
native repository (a Debian one serving its suite, packetfence-X-Y-el<N>) and its file snapshot
(debian / rhel<N>), all visible to ci-packages. They come from the packaging side's release, which also
seeds the next devel with X.Y's packages: every package name X.Y serves must be in that devel too, so the
new devel keeps every dependency (a vX.Y.0 tag stops otherwise; a later vX.Y.Z only warns).
Reads Pulp only and publishes nothing; PULP_URL / PULP_USERNAME / PULP_PASSWORD as for publishing.
"""
import argparse
import os
import re
import sys
from pathlib import Path

sys.path[:0] = [str(Path(__file__).resolve().parent), str(Path(__file__).resolve().parent / 'vendor')]
from pulp_publish import API, Pulp  # noqa: E402
from native import find  # noqa: E402

DEBIAN_CODENAMES = {'10': 'buster', '11': 'bullseye', '12': 'bookworm', '13': 'trixie', '14': 'forky', '15': 'duke'}


def expected(os_list):
    """{(kind, target)} for these OSes (e.g. 'RHEL-8 Debian-12'): ('deb', codename), ('rpm', major), ('file', snapshot)."""
    needed = set()
    for entry in os_list.split():
        family, _, major = entry.partition('-')
        if family == 'Debian' and major in DEBIAN_CODENAMES:
            needed |= {('deb', DEBIAN_CODENAMES[major]), ('file', 'debian')}
        elif family == 'RHEL' and major.isdigit():
            needed |= {('rpm', major), ('file', f'rhel{major}')}
        else:
            raise ValueError('Unknown OS in OS_SUPPORTED: ' + entry)
    return needed


def version(text):
    return tuple(int(part) for part in text.split('.'))


def devel_after(client, release):
    """The newest active public release above X.Y in Pulp (the devel the release seeded), or None."""
    found = set()
    for kind, model in (('deb', 'apt'), ('rpm', 'rpm')):
        for repo in client.request('GET', API + f'repositories/{kind}/{model}/', params={
                'pulp_label_select': 'akainverse_access=public,akainverse_state=active', 'limit': 1000})['results']:
            label = (repo.get('pulp_labels') or {}).get('akainverse_release', '')
            if re.fullmatch(r'[0-9]+\.[0-9]+', label) and version(label) > version(release):
                found.add(label)
    return max(found, key=version) if found else None


def package_names(client, kind, name):
    """Package names in a repository's latest version."""
    model, field = ('apt', 'package') if kind == 'deb' else ('rpm', 'name')
    repo = client.request('GET', API + f'repositories/{kind}/{model}/', params={'name': name})['results'][0]
    names, params = set(), {'repository_version': repo['latest_version_href'], 'fields': field, 'limit': 1000, 'offset': 0}
    while True:
        page = client.request('GET', API + f'content/{kind}/packages/', params=params)
        names |= {item[field] for item in page['results']}
        if not page.get('next'):
            return names
        params['offset'] += params['limit']


def missing_in_devel(client, release, needed, finder=find, devel=None, names=package_names):
    """Problems if the devel after X.Y lacks a package name X.Y serves, per OS."""
    devel = devel or devel_after(client, release)
    if devel is None:
        return [f'no devel after {release} in Pulp: release {release} on the packaging side first']
    found = []
    for kind, target in sorted(k for k in needed if k[0] != 'file'):
        ours, theirs = finder(client, kind, release, target), finder(client, kind, devel, target)
        what = f'Debian suite {target}' if kind == 'deb' else f'EL{target}'
        if not theirs:
            found.append(f'{what}: no active public {devel} repository')
        elif ours:
            lacking = sorted(names(client, kind, ours) - names(client, kind, theirs))
            if lacking:
                found.append(f'{what}: {devel} lacks {len(lacking)} package(s) of {release}: ' + ', '.join(lacking[:20])
                             + (' …' if len(lacking) > 20 else ''))
    return found


def problems(client, release, needed, finder=find):
    found = []
    for kind, target in sorted(needed):
        if kind == 'file':
            if not client.request('GET', API + 'repositories/file/file/', params={'name': target})['results']:
                found.append(f'{target}: missing file snapshot (or not granted to ci-packages yet)')
        elif not finder(client, kind, release, target):
            what = f'Debian suite {target}' if kind == 'deb' else f'EL{target}'
            found.append(f'{what}: no active public {release} repository (or not granted to ci-packages yet)')
    return found


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag', required=True)
    parser.add_argument('--pf-release', type=Path, default=Path('conf/pf-release'))
    parser.add_argument('--os-list', required=True)
    args = parser.parse_args(argv)
    match = re.fullmatch(r'PacketFence (([0-9]+\.[0-9]+)\.[0-9]+)\s*', args.pf_release.read_text())
    if not match:
        sys.exit('Cannot read the version in ' + str(args.pf_release))
    if args.tag != 'v' + match.group(1):
        sys.exit(f'Tag {args.tag} does not match conf/pf-release ({match.group(1)})')
    release = match.group(2)
    client = Pulp(os.environ['PULP_URL'], os.environ['PULP_USERNAME'], os.environ['PULP_PASSWORD'])
    needed = expected(args.os_list)
    found = problems(client, release, needed)
    if found:
        sys.exit(f'Pulp is not ready for {args.tag}; release {release} on the packaging side first:\n  '
                 + '\n  '.join(found))
    devel = missing_in_devel(client, release, needed)
    if devel and args.tag.endswith('.0'):
        sys.exit(f'The devel after {release} misses packages of {args.tag} (seeding):\n  ' + '\n  '.join(devel))
    for line in devel:
        print('warning: ' + line)
    print(f'Pulp is ready for {args.tag} ({release}): ' + args.os_list)


if __name__ == '__main__':
    main()
