#!/usr/bin/env python3
"""Give this pipeline's service images their branch tags (deploy_containers, after the tests).

devel and maintenance/X.Y build jobs push service images only as <slug>-p<pipeline>. This
copies each manifest to the branch tags in the same repository: same bytes, no layer copy, no
rebuild. Images without the pipeline tag (builders, tools) are skipped. Registry credentials
come from KNK_REGISTRY_USER / KNK_REGISTRY_PASSWORD and are never printed.
"""
import argparse
import os
import re
import sys
from pathlib import Path

import requests

MANIFEST_TYPES = ', '.join([
    'application/vnd.oci.image.index.v1+json',
    'application/vnd.oci.image.manifest.v1+json',
    'application/vnd.docker.distribution.manifest.list.v2+json',
    'application/vnd.docker.distribution.manifest.v2+json',
])
TAG = re.compile(r'[a-z0-9][a-z0-9._-]{0,127}')


class Registry:
    def __init__(self, registry, namespace, auth=None):
        self.registry, self.namespace, self.auth = registry, namespace, auth
        self.session = requests.Session()

    def _url(self, image, reference):
        return f'https://{self.registry}/v2/{self.namespace}/{image}/manifests/{reference}'

    def _token(self, image, actions):
        response = self.session.get(f'https://{self.registry}/token', auth=self.auth, timeout=30,
                                    params={'service': self.registry,
                                            'scope': f'repository:{self.namespace}/{image}:{actions}'})
        if response.status_code in (401, 403) and self.auth is None:
            return None  # anonymous: no such public repository
        if response.status_code != 200:
            raise RuntimeError(f'Registry token for {image} failed with HTTP {response.status_code}')
        return {'Authorization': 'Bearer ' + response.json()['token']}

    def manifest(self, image, tag, headers):
        """(bytes, media type, digest) of image:tag, or None when the tag does not exist."""
        response = self.session.get(self._url(image, tag), timeout=60,
                                    headers={**headers, 'Accept': MANIFEST_TYPES})
        # Folders that are not published images (or not under this name) have no such tag.
        if response.status_code in (404,) or (response.status_code in (401, 403) and self.auth is None):
            return None
        if response.status_code != 200:
            raise RuntimeError(f'GET {image}:{tag} failed with HTTP {response.status_code}')
        return response.content, response.headers['Content-Type'], response.headers.get('Docker-Content-Digest')

    def promote(self, image, source, targets, apply):
        headers = self._token(image, 'pull,push' if apply else 'pull')
        if headers is None:
            return None
        found = self.manifest(image, source, headers)
        if found is None:
            return None
        body, media_type, digest = found
        for tag in targets if apply else []:
            response = self.session.put(self._url(image, tag), data=body, timeout=60,
                                        headers={**headers, 'Content-Type': media_type})
            if response.status_code not in (200, 201):
                raise RuntimeError(f'PUT {image}:{tag} failed with HTTP {response.status_code}')
            if digest and response.headers.get('Docker-Content-Digest') not in (None, digest):
                raise RuntimeError(f'{image}:{tag} digest differs from {source}')
        return digest


def image_names(containers):
    return sorted(p.parent.name for p in Path(containers).glob('*/Dockerfile') if not p.is_symlink())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, help='Pipeline tag, e.g. devel-p123')
    parser.add_argument('--tags', required=True, help='Comma-separated branch tags, e.g. devel,latest')
    parser.add_argument('--containers', default='containers')
    parser.add_argument('--require', default='pfdebian,radiusd,pfcmd', help='Images that must be promoted')
    parser.add_argument('--apply', action='store_true', help='Without it, only check the pipeline tags exist')
    args = parser.parse_args()
    targets = [t for t in args.tags.split(',') if t]
    if not TAG.fullmatch(args.source) or not targets or not all(TAG.fullmatch(t) for t in targets):
        print('Invalid --source or --tags', file=sys.stderr)
        return 2
    registry, _, namespace = os.environ['KNK_REGISTRY_URL'].partition('/')
    auth = None
    if args.apply:
        auth = (os.environ['KNK_REGISTRY_USER'], os.environ['KNK_REGISTRY_PASSWORD'])
    client = Registry(registry, namespace, auth)
    promoted = {}
    try:
        for image in image_names(args.containers):
            digest = client.promote(image, args.source, targets, args.apply)
            if digest is not None:
                promoted[image] = digest
                print(f'{image}:{args.source} -> {",".join(targets)} {digest or ""}'.rstrip())
    except (RuntimeError, requests.RequestException) as exc:
        print(f'Promotion failed: {exc}', file=sys.stderr)
        return 1
    missing = [i for i in args.require.split(',') if i and i not in promoted]
    if missing:
        print(f'No {args.source} tag for required images: {", ".join(missing)}', file=sys.stderr)
        return 1
    print(f'{"Promoted" if args.apply else "Would promote"} {len(promoted)} images to {",".join(targets)}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
