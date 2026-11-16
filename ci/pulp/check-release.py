#!/usr/bin/env python3
"""Stop a release tag pipeline early when Pulp is not ready for it (check stage, before any build).

The tag must match conf/pf-release, and for X.Y every OS in OS_SUPPORTED must have an active public
native repository (a Debian one serving its suite, packetfence-X-Y-el<N>) and its file snapshot
(debian / rhel<N>), all visible to ci-packages. They come from the packaging side's release.
Reads Pulp only; PULP_URL / PULP_USERNAME / PULP_PASSWORD as for publishing.
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
    found = problems(client, release, expected(args.os_list))
    if found:
        sys.exit(f'Pulp is not ready for {args.tag}; release {release} on the packaging side first:\n  '
                 + '\n  '.join(found))
    print(f'Pulp is ready for {args.tag} ({release}): ' + args.os_list)


if __name__ == '__main__':
    main()
