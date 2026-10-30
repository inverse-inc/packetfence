#!/usr/bin/env python3
"""Plan and import public PacketFence maintenance/development images into Pulp.

Plan and size are read-only. Provision and sync need --apply. Image bytes travel GHCR -> Pulp.
Serialize all writers with the same external/GitLab resource lock.
"""
import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urljoin, urlsplit

import requests
from pulp_publish import API, Pulp

LABEL = {'akainverse_container_mirror': 'true'}
PREFIX = 'inverse-inc/packetfence/'
MEDIA = ', '.join(['application/vnd.oci.image.index.v1+json',
                   'application/vnd.docker.distribution.manifest.list.v2+json',
                   'application/vnd.oci.image.manifest.v1+json',
                   'application/vnd.docker.distribution.manifest.v2+json'])
INDEX_TYPES = {'application/vnd.oci.image.index.v1+json',
               'application/vnd.docker.distribution.manifest.list.v2+json'}
MANIFEST_TYPES = {'application/vnd.oci.image.manifest.v1+json',
                  'application/vnd.docker.distribution.manifest.v2+json'}
DEVEL_TAGS = {'devel', 'latest', 'maintenance-99-9'}


def image_name(value):
    if not re.fullmatch(r'[a-z0-9]+(?:[._-][a-z0-9]+)*', value):
        raise ValueError('Invalid image name')
    return value


def maintenance_tag(value):
    if not re.fullmatch(r'maintenance-\d+-\d+', value) and value not in DEVEL_TAGS:
        raise ValueError('Expected a maintenance or development image tag')
    return value


def branch_tag(value):
    if value == 'devel':
        return value
    if not re.fullmatch(r'maintenance/\d+\.\d+', value):
        raise ValueError('Branch must be maintenance/X.Y or devel')
    return maintenance_tag(value.replace('/', '-').replace('.', '-'))


class GHCR:
    """Anonymous public pull only; never receive Pulp credentials."""
    def __init__(self):
        self.tokens = {}

    def get(self, image, path):
        image_name(image)
        url = urljoin('https://ghcr.io', path)
        p = urlsplit(url)
        if p.scheme != 'https' or p.netloc != 'ghcr.io' or not p.path.startswith('/v2/'+PREFIX+image+'/'):
            raise ValueError('Registry pagination escaped the approved image')
        if image not in self.tokens:
            r = requests.get('https://ghcr.io/token', params={'service': 'ghcr.io',
                'scope': 'repository:'+PREFIX+image+':pull'}, timeout=(15, 60), allow_redirects=False)
            if r.status_code != 200:
                raise RuntimeError('Cannot obtain public pull token for '+image+': HTTP '+str(r.status_code))
            self.tokens[image] = r.json()['token']
        r = requests.get(url, headers={'Authorization': 'Bearer '+self.tokens[image], 'Accept': MEDIA},
                         timeout=(15, 120), allow_redirects=False)
        if r.status_code != 200:
            raise RuntimeError('GHCR read failed for '+image+': HTTP '+str(r.status_code))
        return r

    def tags(self, image):
        path = '/v2/'+PREFIX+image+'/tags/list?n=100'
        tags, visited = set(), set()
        while path:
            if path in visited:
                raise RuntimeError('Repeated registry pagination link')
            visited.add(path)
            r = self.get(image, path)
            tags.update(r.json().get('tags') or [])
            path = r.links.get('next', {}).get('url')
        return tags

    def digest(self, image, tag):
        maintenance_tag(tag)
        r = self.get(image, '/v2/'+PREFIX+image+'/manifests/'+tag)
        digest = 'sha256:'+hashlib.sha256(r.content).hexdigest()
        if r.headers.get('Docker-Content-Digest', digest) != digest:
            raise ValueError('Registry manifest digest mismatch')
        if r.json().get('schemaVersion') != 2:
            raise ValueError('Only OCI/Docker schema 2 manifests are supported')
        return digest

    def manifest(self, image, digest):
        if not re.fullmatch(r'sha256:[a-f0-9]{64}', digest):
            raise ValueError('Invalid manifest digest')
        response = self.get(image, '/v2/'+PREFIX+image+'/manifests/'+digest)
        if response.headers.get('Docker-Content-Digest', digest) != digest:
            raise ValueError('Registry manifest digest mismatch')
        return response.content


def plan(catalog, branches, registry, include_devel=False):
    wanted = {branch_tag(b) for b in branches}
    if wanted & DEVEL_TAGS or (wanted and include_devel):
        wanted |= DEVEL_TAGS
    images = catalog['images']
    if catalog.get('schema') != 1 or not images or len(set(images)) != len(images):
        raise ValueError('Invalid image catalog')
    entries, omitted = [], []
    for image in sorted(images):
        image_name(image)
        tags = registry.tags(image)
        selected = sorted(t for t in tags if
                          ((re.fullmatch(r'maintenance-\d+-\d+', t) and t not in DEVEL_TAGS)
                           or (t in DEVEL_TAGS and (include_devel or wanted & DEVEL_TAGS)))
                          and (not wanted or t in wanted))
        if not selected:
            omitted.append(image)
        for tag in selected:
            entries.append({'image': image, 'tag': tag, 'digest': registry.digest(image, tag)})
    if not entries:
        raise ValueError('No maintenance images found')
    return {'schema': 1, 'source': 'ghcr.io/'+PREFIX.rstrip('/'),
            'created_at': datetime.now(timezone.utc).isoformat(), 'entries': entries,
            'requested_branches': branches, 'include_devel': include_devel,
            'images_without_matching_tags': omitted}


def validate_plan(value):
    if value.get('schema') != 1 or value.get('source') != 'ghcr.io/'+PREFIX.rstrip('/') or not value.get('entries'):
        raise ValueError('Invalid import plan')
    seen = set()
    for e in value['entries']:
        key = image_name(e['image']), maintenance_tag(e['tag'])
        if key in seen or not re.fullmatch(r'sha256:[a-f0-9]{64}', e['digest']):
            raise ValueError('Duplicate image/tag or invalid digest')
        seen.add(key)
    return value['entries']


def measure(value, registry):
    """Measure compressed descriptors; fetch manifests only, never image blobs.

    Count all platforms and assume no artifacts are already present in Pulp.
    This is a content-size upper bound, not filesystem/DB allocation accounting.
    """
    entries = validate_plan(value)
    sizes, blobs, manifests, cache = {}, set(), set(), {}
    images = {}

    def remember(digest, size):
        if (not isinstance(digest, str) or not re.fullmatch(r'sha256:[a-f0-9]{64}', digest)
                or type(size) is not int or size < 0):
            raise ValueError('Invalid content digest or descriptor size')
        if digest in sizes and sizes[digest] != size:
            raise ValueError('Conflicting sizes for the same content digest')
        sizes[digest] = size

    def descriptor(item):
        if not isinstance(item, dict):
            raise ValueError('Invalid manifest descriptor')
        digest, size = item.get('digest'), item.get('size')
        remember(digest, size)
        return digest

    def walk(image, digest, image_blobs, image_manifests, depth=0, expected_type=None):
        if depth > 32:
            raise ValueError('Manifest index nesting exceeds limit')
        if digest not in cache:
            raw = registry.manifest(image, digest)
            if 'sha256:'+hashlib.sha256(raw).hexdigest() != digest:
                raise ValueError('Manifest bytes do not match the planned digest')
            remember(digest, len(raw))
            document = json.loads(raw)
            if not isinstance(document, dict) or document.get('schemaVersion') != 2:
                raise ValueError('Only OCI/Docker schema 2 manifests are supported')
            cache[digest] = document
        document = cache[digest]
        media_type = document.get('mediaType') or expected_type
        if media_type and media_type not in INDEX_TYPES | MANIFEST_TYPES:
            raise ValueError('Unsupported manifest media type')
        if expected_type and media_type != expected_type:
            raise ValueError('Manifest media type differs from its descriptor')
        if digest in image_manifests:
            return
        image_manifests.add(digest)
        manifests.add(digest)
        # OCI permits omission of mediaType; the schema still identifies the form.
        is_index = media_type in INDEX_TYPES or (not media_type and 'manifests' in document)
        if is_index:
            children = document.get('manifests')
            if not isinstance(children, list) or not children:
                raise ValueError('Manifest index has no platform descriptors')
            for child in children:
                child_digest = descriptor(child)
                child_type = child.get('mediaType')
                if child_type not in INDEX_TYPES | MANIFEST_TYPES:
                    raise ValueError('Unsupported child manifest media type')
                walk(image, child_digest, image_blobs, image_manifests, depth+1, child_type)
        else:
            layers = document.get('layers')
            if not isinstance(layers, list):
                raise ValueError('Manifest has no layer descriptors')
            for item in [document.get('config')] + layers:
                blob = descriptor(item)
                blobs.add(blob)
                image_blobs.add(blob)

    def totals(blob_set, manifest_set):
        return {'unique_blob_count': len(blob_set),
                'unique_blob_bytes': sum(sizes[d] for d in blob_set),
                'unique_manifest_count': len(manifest_set),
                'unique_manifest_bytes': sum(sizes[d] for d in manifest_set),
                'total_unique_bytes': sum(sizes[d] for d in blob_set | manifest_set)}

    for entry in entries:
        image_blobs, image_manifests = images.setdefault(entry['image'], (set(), set()))
        walk(entry['image'], entry['digest'], image_blobs, image_manifests)
    per_image = [{'image': image, **totals(*sets)} for image, sets in sorted(images.items())]
    result = {'schema': 1, 'source': value['source'],
              'entries': [{'image': e['image'], 'tag': e['tag'], 'digest': e['digest']} for e in entries],
              'assumption': 'All platforms; compressed descriptor sizes; no existing Pulp artifact reuse assumed.',
              **totals(blobs, manifests), 'images': per_image}
    result['largest_image_bytes'] = max(image['total_unique_bytes'] for image in per_image)
    result['bytes_shared_between_images'] = sum(image['total_unique_bytes'] for image in per_image) - result['total_unique_bytes']
    return result


def require_capacity(client, content_bytes, temporary_bytes, min_free_bytes):
    storage = client.request('GET', API+'status/').get('storage') or {}
    free = storage.get('free')
    required = content_bytes + temporary_bytes + min_free_bytes
    if type(free) is not int or free < required:
        raise RuntimeError('Insufficient or unknown free artifact storage: need '+str(required)+
                           ' bytes including temporary space and reserve; available '+str(free))
    return {'free_bytes': free, 'required_bytes': required, 'reserve_bytes': min_free_bytes}


def name(image):
    return 'pf-ghcr-'+image_name(image)


def find(client, endpoint, object_name):
    page = client.request('GET', API+endpoint+'/', params={'name': object_name})
    if page['count'] > 1:
        raise ValueError('Duplicate Pulp object name')
    return page['results'][0] if page['count'] else None


def ensure(client, endpoint, desired):
    obj = find(client, endpoint, desired['name'])
    if obj is None:
        client.wait(client.request('POST', API+endpoint+'/', json=desired))
        obj = client.find(endpoint, desired['name'])
    if obj.get('pulp_labels', {}).get('akainverse_container_mirror') != 'true':
        raise ValueError('Refusing to adopt an unmanaged container object')
    return obj


def check_remote(remote, image, tag):
    includes = remote.get('includes', remote.get('include_tags'))
    excludes = remote.get('excludes', remote.get('exclude_tags'))
    if (remote.get('pulp_labels', {}).get('akainverse_container_mirror') != 'true'
            or remote['url'].rstrip('/') != 'https://ghcr.io' or remote['upstream_name'] != PREFIX+image
            or includes != [tag] or excludes or remote['policy'] != 'immediate'
            or remote.get('tls_validation') is False):
        raise ValueError('Remote must pin this public GHCR image and exact maintenance tag')


def check_destination(repo, dist, image):
    if (repo.get('pulp_labels', {}).get('akainverse_container_mirror') != 'true'
            or dist.get('pulp_labels', {}).get('akainverse_container_mirror') != 'true'
            or repo.get('retain_repo_versions') not in (None, 1) or dist.get('repository')
            or dist.get('private') is not False or not dist.get('content_guard')
            or dist['base_path'] != PREFIX+image or not dist.get('repository_version')
            or not dist['repository_version'].startswith(repo['pulp_href']+'versions/')):
        raise ValueError('Destination must be a managed public version-pinned mirror with valid retention')


def provision(client, value, apply=False, latest_only=False):
    entries = validate_plan(value)
    if not apply:
        return {'applied': False, 'images': sorted({e['image'] for e in entries}), 'remotes': len(entries)}
    for image in sorted({e['image'] for e in entries}):
        repo = ensure(client, 'repositories/container/container',
                      {'name': name(image), 'pulp_labels': LABEL, 'retain_repo_versions': 1 if latest_only else None})
        existing_dist = find(client, 'distributions/container/container', name(image))
        if repo.get('retain_repo_versions') not in (None, 1):
            raise ValueError('Unexpected container version retention policy')
        if latest_only and repo.get('retain_repo_versions') != 1:
            client.wait(client.request('PATCH', repo['pulp_href'], json={'retain_repo_versions': 1}))
            repo = client.request('GET', repo['pulp_href'])
        if existing_dist is None and not repo['latest_version_href'].endswith('/versions/0/'):
            raise ValueError('Refusing to expose an existing populated repository during provisioning')
        dist = ensure(client, 'distributions/container/container', {'name': name(image), 'pulp_labels': LABEL,
                      'base_path': PREFIX+image, 'private': False, 'repository_version': repo['latest_version_href']})
        check_destination(repo, dist, image)
    for e in entries:
        remote = ensure(client, 'remotes/container/container', {'name': name(e['image'])+'-'+e['tag'],
            'pulp_labels': LABEL, 'url': 'https://ghcr.io', 'upstream_name': PREFIX+e['image'],
            'include_tags': [e['tag']], 'policy': 'immediate', 'tls_validation': True})
        check_remote(remote, e['image'], e['tag'])
    return {'applied': True, 'repositories': sorted({name(e['image']) for e in entries}), 'remotes': len(entries)}


def tags_at(client, version):
    tags, offset = {}, 0
    while True:
        page = client.request('GET', API+'content/container/tags/',
                              params={'repository_version': version, 'limit': 1000, 'offset': offset})
        for tag in page['results']:
            if tag['name'] in tags:
                raise ValueError('Duplicate tag in repository version')
            tags[tag['name']] = client.request('GET', tag['tagged_manifest'])['digest']
        offset += len(page['results'])
        if offset >= page['count']:
            return tags
        if not page['results']:
            raise RuntimeError('Incomplete tag pagination')


def sync(client, value, registry, apply=False, allow_tag_update=False, checkpoint=None,
         min_free_bytes=15*1024**3):
    if type(min_free_bytes) is not int or min_free_bytes < 1:
        raise ValueError('Free-space reserve must be positive')
    entries = validate_plan(value)
    jobs, changes = {}, []
    # Preflight the complete plan before issuing any mutation.
    for e in entries:
        image, tag = e['image'], e['tag']
        if image not in jobs:
            repo = client.find('repositories/container/container', name(image))
            dist = client.find('distributions/container/container', name(image))
            check_destination(repo, dist, image)
            if repo['latest_version_href'] != dist['repository_version']:
                raise ValueError('Unpublished repository version exists; review/recover before another sync')
            jobs[image] = {'repo': repo, 'dist': dist, 'before': tags_at(client, dist['repository_version']), 'entries': []}
        job = jobs[image]
        remote = client.find('remotes/container/container', name(image)+'-'+tag)
        check_remote(remote, image, tag)
        if registry.digest(image, tag) != e['digest']:
            raise ValueError('GHCR tag moved since planning; regenerate and review the plan')
        old = job['before'].get(tag)
        if old and old != e['digest']:
            changes.append({'image': image, 'tag': tag, 'previous': old, 'new': e['digest']})
        job['entries'].append((e, remote))
    if changes and not allow_tag_update:
        raise ValueError('Existing maintenance tag digest differs; review a new plan and use --allow-tag-update explicitly')
    result = {'applied': False, 'tag_updates': changes, 'repositories': []}
    pending = [e for job in jobs.values() for e, _ in job['entries']
               if job['before'].get(e['tag']) != e['digest']]
    image_sizes = {}
    if pending:
        capacity = measure({**value, 'entries': pending}, registry)
        capacity['storage_check'] = require_capacity(client, capacity['total_unique_bytes'],
                                                    capacity['largest_image_bytes'], min_free_bytes)
        result['capacity'] = capacity
        image_sizes = {image['image']: image['total_unique_bytes'] for image in capacity['images']}
    result['repositories'] = [{'image': image, 'previous_version': job['dist']['repository_version'],
                               'repository_version': job['repo']['latest_version_href']} for image, job in jobs.items()]
    if not apply:
        return result
    if checkpoint:
        checkpoint(result)
    for image, job in jobs.items():
        repo, dist = job['repo'], job['dist']
        version = repo['latest_version_href']
        expected = dict(job['before'])
        for e, remote in job['entries']:
            if expected.get(e['tag']) == e['digest']:
                continue
            if client.request('GET', repo['pulp_href'])['latest_version_href'] != version:
                raise RuntimeError('Concurrent repository writer detected')
            # Recheck immediately before each serialized download. Allow another
            # full image footprint for temporary files, without assuming reuse.
            require_capacity(client, image_sizes[image], image_sizes[image], min_free_bytes)
            client.wait(client.request('POST', repo['pulp_href']+'sync/',
                                       json={'remote': remote['pulp_href'], 'mirror': False}))
            version = client.request('GET', repo['pulp_href'])['latest_version_href']
            expected[e['tag']] = e['digest']
            if tags_at(client, version) != expected:
                raise RuntimeError('Imported digests/tags differ from plan; distribution was not changed')
        job['version'] = version
        record = next(r for r in result['repositories'] if r['image'] == image)
        record.update(repository_version=version, tags=expected)
        if checkpoint:
            checkpoint(result)
    # Verify all imports before switching any public distribution.
    for job in jobs.values():
        current = client.request('GET', job['dist']['pulp_href'])
        if (any(current.get(k) != job['dist'].get(k) for k in
                ('repository_version', 'repository', 'base_path', 'private', 'content_guard'))
                or client.request('GET', job['repo']['pulp_href'])['latest_version_href'] != job['version']):
            raise RuntimeError('Concurrent distribution/repository change detected')
    for job in jobs.values():
        if job['version'] != job['dist']['repository_version']:
            client.wait(client.request('PATCH', job['dist']['pulp_href'], json={'repository_version': job['version']}))
    result['applied'] = True
    return result


def write_report(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name+'.tmp')
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True)+'\n')
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    p = sub.add_parser('plan')
    p.add_argument('--catalog', type=Path, required=True)
    p.add_argument('--branch', action='append', default=[])
    p.add_argument('--include-devel', action='store_true', help='Include devel, latest and maintenance-99-9 aliases')
    p.add_argument('--require-all-images', action='store_true')
    p.add_argument('--output', type=Path, required=True)
    p = sub.add_parser('size', help='Measure unique compressed blobs and manifests without downloading blobs')
    p.add_argument('--plan', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    for action in ('provision', 'sync'):
        p = sub.add_parser(action)
        p.add_argument('--plan', type=Path, required=True)
        p.add_argument('--output', type=Path, required=True)
        p.add_argument('--apply', action='store_true')
        if action == 'sync':
            p.add_argument('--allow-tag-update', action='store_true')
            p.add_argument('--min-free-gib', type=int, default=15)
    args = parser.parse_args()
    try:
        if args.action == 'plan':
            result = plan(json.loads(args.catalog.read_text()), args.branch, GHCR(), args.include_devel)
            if args.require_all_images and result['images_without_matching_tags']:
                raise ValueError('Catalog images missing requested maintenance tags: '+', '.join(result['images_without_matching_tags']))
        elif args.action == 'size':
            result = measure(json.loads(args.plan.read_text()), GHCR())
        else:
            value = json.loads(args.plan.read_text())
            client = Pulp(os.environ['PULP_URL'], os.environ['PULP_USERNAME'], os.environ['PULP_PASSWORD'], timeout=7200)
            result = (provision(client, value, args.apply) if args.action == 'provision' else
                      sync(client, value, GHCR(), args.apply, args.allow_tag_update,
                           checkpoint=lambda report: write_report(args.output, report),
                           min_free_bytes=args.min_free_gib*1024**3))
        write_report(args.output, result)
        if result.get('images_without_matching_tags'):
            print('WARNING: no matching maintenance tags: '+', '.join(result['images_without_matching_tags']), file=sys.stderr)
        print('Wrote '+str(args.output))
    except (KeyError, ValueError, RuntimeError, OSError, requests.RequestException) as exc:
        print('Container import failed: '+str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
