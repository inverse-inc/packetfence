#!/usr/bin/env python3
"""Upload binary packages, sign an exact version, then switch one distribution.

Serialize jobs per repository in CI. Credentials come only from the environment.
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path
from urllib.parse import urlsplit

import requests

API = '/pulp/api/v3/'
TYPES = {'deb': 'apt', 'rpm': 'rpm'}


class Pulp:
    def __init__(self, url, username, password, timeout=1800):
        parsed = urlsplit(url)
        if (parsed.scheme != 'https' or not parsed.hostname or parsed.username
                or parsed.password or parsed.path not in ('', '/') or parsed.query or parsed.fragment):
            raise ValueError('PULP_URL must be an HTTPS origin without credentials or a path')
        self.url = url.rstrip('/')
        self.timeout = timeout
        self.session = requests.Session()
        self.session.auth = (username, password)
        # REQUESTS_CA_BUNDLE supports an internal CA; TLS verification stays on.

    def request(self, method, href, **kwargs):
        if not href.startswith(API) or '..' in href or '?' in href or '#' in href:
            raise ValueError('Unexpected Pulp API reference')
        response = self.session.request(method, self.url + href, timeout=(15, 300),
                                        allow_redirects=False, **kwargs)
        if not 200 <= response.status_code < 300:
            # Do not dump response bodies: errors can include credentials or submitted data.
            raise RuntimeError(f'Pulp {method} failed with HTTP {response.status_code}')
        return response.json() if response.content else {}

    def find(self, endpoint, name):
        data = self.request('GET', API + endpoint + '/', params={'name': name})
        if data['count'] != 1:
            raise ValueError(f'Expected exactly one {endpoint} named {name}')
        return data['results'][0]

    def wait(self, response):
        if 'task' not in response:
            return response
        deadline = time.monotonic() + self.timeout
        while time.monotonic() < deadline:
            task = self.request('GET', response['task'])
            if task['state'] == 'completed':
                return task
            if task['state'] in ('failed', 'canceled', 'canceling', 'skipped'):
                raise RuntimeError(f'Pulp task {task["state"]}: {response["task"]}')
            time.sleep(2)
        raise TimeoutError('Pulp task timed out; inspect it before retrying')

    def upload(self, endpoint, path, data):
        # requests-toolbelt streams the package instead of buffering it in RAM.
        from requests_toolbelt.multipart.encoder import MultipartEncoder
        with path.open('rb') as source:
            body = MultipartEncoder(fields={**data, 'file': (path.name, source, 'application/octet-stream')})
            return self.wait(self.request('POST', endpoint, data=body,
                                         headers={'Content-Type': body.content_type}))


def publish(client, kind, name, paths, codename=None, component='main', guard=None, release=None,
            sync=None):
    if kind not in TYPES or (not paths and sync is None):
        raise ValueError('Provide a package type and at least one package')
    if paths and sync is not None:
        raise ValueError('Use either uploads or synchronization, not both')
    if kind == 'deb' and not codename:
        raise ValueError('Debian uploads require --codename')
    paths = [Path(path) for path in paths]
    if any(not path.is_file() or path.suffix != '.' + kind for path in paths):
        raise ValueError('Every input must be an existing binary package of the selected type')
    model = TYPES[kind]
    repo = client.find(f'repositories/{kind}/{model}', name)
    labels = repo.get('pulp_labels', {})
    if labels.get('akainverse_state') != 'active':
        raise ValueError('Repository is frozen or not managed by this deployment')
    if labels.get('akainverse_release', '') != (release or ''):
        raise ValueError('--release must match the configured PacketFence release')
    if kind == 'deb' and (labels.get('akainverse_distribution') != codename
                         or labels.get('akainverse_component') != component):
        raise ValueError('Codename/component does not match the repository definition')
    dist = client.find(f'distributions/{kind}/{model}', name)
    expected_guard = client.find('contentguards/core/rbac', guard)['pulp_href'] if guard else None
    if dist.get('content_guard') != expected_guard:
        raise ValueError('Distribution content guard does not match --guard (or public access)')
    if dist['base_path'].startswith('addons/') and not expected_guard:
        raise ValueError('Refusing to publish private addons without a content guard')
    if labels.get('akainverse_access') == 'private' and not expected_guard:
        raise ValueError('Private repository requires --guard')
    if dist.get('repository'):
        raise ValueError('Distribution must pin a publication, not track a repository')
    signing_field = 'signing_service' if kind == 'deb' else 'metadata_signing_service'
    signer = repo.get(signing_field)
    if not signer:
        raise ValueError('Repository has no metadata signing service')
    old_publication = dist.get('publication')
    data = {'repository': repo['pulp_href']}
    if kind == 'deb':
        data.update(distribution=codename, component=component)
    if sync is not None:
        sync(client, repo)
    else:
        for path in paths:
            client.upload(API + f'content/{kind}/packages/', path, data)
    version = client.request('GET', repo['pulp_href'])['latest_version_href']
    layout = 'nested_alphabetically' if kind == 'deb' else 'flat'
    publication_data = {'repository_version': version, 'layout': layout}
    if kind == 'deb':
        publication_data.update(signing_service=signer, simple=False, structured=True,
                                publish_upstream_release_fields=True,
                                publish_legacy_release_files=True)
    task = client.wait(client.request('POST', API + f'publications/{kind}/{model}/',
                                      json=publication_data))
    prefix = API + f'publications/{kind}/{model}/'
    publications = [href for href in task.get('created_resources', []) if href.startswith(prefix)]
    if len(publications) != 1:
        raise RuntimeError('Publication task did not return exactly one publication')
    publication = client.request('GET', publications[0])
    if publication['repository_version'] != version:
        raise RuntimeError('Publication does not match the uploaded repository version')
    if publication.get('layout') != layout:
        raise RuntimeError('Publication layout does not preserve the configured client paths')
    current = client.request('GET', dist['pulp_href'])
    if (current.get('publication') != old_publication
            or current.get('content_guard') != expected_guard or current.get('repository')):
        raise RuntimeError('Distribution changed during publish; serialize jobs and retry after review')
    # Never create distributions or alter access controls from CI.
    client.wait(client.request('PATCH', dist['pulp_href'], json={'publication': publications[0]}))
    return {'repository': name, 'repository_version': version,
            'publication': publications[0], 'previous_publication': old_publication,
            'base_url': dist['base_url']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('type', choices=TYPES)
    parser.add_argument('repository')
    parser.add_argument('packages', nargs='+')
    parser.add_argument('--codename')
    parser.add_argument('--component', default='main')
    parser.add_argument('--guard', help='Required RBAC guard name for private repositories')
    parser.add_argument('--release', help='Required for release-specific repositories, e.g. 15.2')
    parser.add_argument('--task-timeout', type=int, default=1800)
    args = parser.parse_args()
    try:
        client = Pulp(os.environ['PULP_URL'], os.environ['PULP_USERNAME'],
                      os.environ['PULP_PASSWORD'], args.task_timeout)
        print(json.dumps(publish(client, args.type, args.repository, args.packages,
                                 args.codename, args.component, args.guard, args.release), indent=2))
    except (KeyError, ValueError, RuntimeError, TimeoutError, OSError, requests.RequestException) as exc:
        print(f'Publish failed: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
