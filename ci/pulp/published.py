#!/usr/bin/env python3
"""Whether a repository already serves this package version (name, version, architecture; release for RPM).

A released version is never replaced by a rebuild. Usage: published.py deb|rpm <repository> <package file>.
Exit 0: already there; 1: not there; 2: the lookup or the package could not be read.
"""
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / 'vendor'))
from pulp_publish import API, Pulp  # noqa: E402


def identity(kind, path):
    """The fields Pulp filters a package on."""
    if kind == 'deb':
        fields = subprocess.run(['dpkg-deb', '-f', str(path), 'Package', 'Version', 'Architecture'],
                                check=True, capture_output=True, text=True).stdout
        values = dict(line.split(': ', 1) for line in fields.splitlines() if ': ' in line)
        return {'package': values['Package'], 'version': values['Version'], 'architecture': values['Architecture']}
    import rpm
    transactions = rpm.TransactionSet()
    transactions.setVSFlags(-1)  # read the header only; Pulp checks the signature
    with open(path, 'rb') as source:
        header = transactions.hdrFromFdno(source.fileno())
    return {'name': header['name'], 'version': header['version'], 'release': header['release'], 'arch': header['arch']}


def published(client, kind, repository, fields):
    model = 'apt' if kind == 'deb' else 'rpm'
    # What the distribution serves, not the latest version: a package uploaded by a publish that then failed
    # ("Distribution changed during publish") is published again by a re-run.
    served = client.find(f'distributions/{kind}/{model}', repository).get('publication')
    if not served:
        return False
    version = client.request('GET', served)['repository_version']
    found = client.request('GET', API + f'content/{kind}/packages/',
                           params={**fields, 'repository_version': version, 'limit': 1})
    return found['count'] > 0


if __name__ == '__main__':
    kind, repository, package = sys.argv[1:4]
    try:
        fields = identity(kind, package)
        there = published(Pulp(os.environ['PULP_URL'], os.environ['PULP_USERNAME'], os.environ['PULP_PASSWORD']),
                          kind, repository, fields)
    except Exception as error:  # a failed lookup must not look like "not published"
        print(f'published.py: {error}', file=sys.stderr)
        sys.exit(2)
    print(' '.join(str(v) for v in fields.values()))
    sys.exit(0 if there else 1)
