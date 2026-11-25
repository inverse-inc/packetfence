#!/usr/bin/env python3
"""Name of the native repository that serves a release for one OS, from its Pulp labels.

A Debian suite is either a repository's own distribution or one of its extra ones (a newer Debian
added to the same URL); EL<N> has its own packetfence-X-Y-el<N>. Usage: native.py deb 16.0 trixie,
native.py rpm 16.0 8. Prints nothing (exit 1) when there is none; exit 2 when Pulp does not answer.
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / 'vendor'))
from pulp_publish import API, Pulp  # noqa: E402


def find(client, kind, release, target):
    model = 'apt' if kind == 'deb' else 'rpm'
    found = client.request('GET', API + f'repositories/{kind}/{model}/', params={
        'pulp_label_select': f'akainverse_release={release},akainverse_access=public,akainverse_state=active',
        'limit': 100})['results']
    for repo in found:
        labels = repo.get('pulp_labels') or {}
        if kind == 'rpm' and repo['name'] == f'packetfence-{release.replace(".", "-")}-el{target}':
            return repo['name']
        extra = [e for e in labels.get('akainverse_extra_distributions', '').split(',') if e]
        if kind == 'deb' and target in [labels.get('akainverse_distribution')] + extra:
            return repo['name']
    return None


if __name__ == '__main__':
    kind, release, target = sys.argv[1:4]
    try:
        name = find(Pulp(os.environ['PULP_URL'], os.environ['PULP_USERNAME'], os.environ['PULP_PASSWORD']), kind, release, target)
    except Exception as error:  # an unanswered lookup is not "no repository": exit 2, the caller fails
        print(f'native.py: Pulp lookup failed: {error}', file=sys.stderr)
        sys.exit(2)
    if not name:
        sys.exit(1)
    print(name)
