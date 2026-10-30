#!/usr/bin/env python3
"""Lock public dependency snapshots and append immutable, pre-signed CI trees.

The generator (PacketFence's generate-pages.sh) owns APT/RPM metadata. This
transport deliberately uses pulp_file, so .dsc/SRPMs and signed bytes survive.
Serialize ALL publishers of the configured destination repository.
"""
import argparse
import csv
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import quote, urlsplit

import requests
from pulp_publish import API, Pulp

SCHEMA = 1
TARGETS = {'debian/bookworm': ('deb', 'amd64'), 'centos/8': ('rpm', 'x86_64')}


def digest(path):
    with Path(path).open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, sort_keys=True, indent=2) + '\n')
    temporary.replace(path)


def safe_path(value):
    if (not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9_+~.:/-]+', value)
            or value.startswith('/') or any(p in ('', '.', '..') for p in value.split('/'))):
        raise ValueError('Unsafe relative package path')
    return value


def origin(value):
    p = urlsplit(value)
    if (p.scheme != 'https' or not p.hostname or p.username or p.password
            or p.path not in ('', '/') or p.query or p.fragment):
        raise ValueError('Content origin must be HTTPS, without a path or credentials')
    return value.rstrip('/')


def read_public(url):
    # Never forward management credentials to the content service or follow a redirect.
    response = requests.get(url, timeout=(15, 300), allow_redirects=False)
    if response.status_code != 200:
        raise RuntimeError(f'Public content GET failed with HTTP {response.status_code}')
    return response.content


def parse_manifest(data):
    files = {}
    for row in csv.reader(data.decode('utf-8').splitlines()):
        if len(row) != 3:
            raise ValueError('Invalid PULP_MANIFEST row')
        name, sha, size = row
        safe_path(name)
        if name in files or not re.fullmatch('[a-f0-9]{64}', sha) or not size.isdecimal():
            raise ValueError('Duplicate path or invalid manifest checksum/size')
        files[name] = {'path': name, 'sha256': sha, 'size': int(size)}
    return files


def snapshot(client, name, content_origin):
    dist = client.find('distributions/file/file', name)
    if dist.get('content_guard') or dist.get('repository') or not dist.get('publication'):
        raise ValueError('Dependency source must pin a public file publication')
    pub = client.request('GET', dist['publication'])
    base = safe_path(dist['base_path'])
    url = origin(content_origin) + '/pulp/content/' + quote(base, safe='/') + '/'
    data = read_public(url + 'PULP_MANIFEST')
    current = client.request('GET', dist['pulp_href'])
    if any(current.get(k) != dist.get(k) for k in ('publication', 'repository', 'content_guard', 'base_path')):
        raise RuntimeError('Dependency distribution changed while locking; retry resolution')
    return {'distribution': name, 'publication': dist['publication'],
            'repository_version': pub['repository_version'], 'base_url': url,
            'manifest_sha256': hashlib.sha256(data).hexdigest()}, parse_manifest(data)


def resolve(client, policy, release, base, content_origin, overrides=None):
    if policy.get('schema') != SCHEMA or not re.fullmatch(r'\d+\.\d+', release):
        raise ValueError('Invalid policy schema or PacketFence release')
    selected = policy['bases'][base]
    if selected['release'] != release:
        raise ValueError('Selected dependency base does not match conf/pf-release')
    if not selected['targets'] or not set(selected['targets']) <= set(TARGETS):
        raise ValueError('Supported targets are Debian bookworm/amd64 and EL8/x86_64')
    overrides = overrides or []
    cache, targets = {}, {}
    def source(name):
        if name not in cache:
            cache[name] = snapshot(client, name, content_origin)
        return cache[name]
    for target, config in selected['targets'].items():
        kind, architecture = TARGETS[target]
        ref, files = source(config['distribution'])
        prefix = config.get('prefix', '')
        if prefix:
            safe_path(prefix.rstrip('/'))
            if not prefix.endswith('/'):
                raise ValueError('A source prefix must end with /')
        packages = [dict(f) for p, f in sorted(files.items())
                    if p.startswith(prefix) and p.endswith('.' + kind)
                    and not p.endswith(('.src.rpm', '.nosrc.rpm'))]
        if not packages:
            raise ValueError('Dependency base contains no binary packages for ' + target)
        for f in packages:
            f['url'] = ref['base_url'] + quote(f['path'], safe='/')
        targets[target] = {'source': ref, 'packages': packages, 'overrides': [],
                           'architecture': architecture}
    for override in overrides:
        target = override['target']
        if target not in targets or override['distribution'] not in selected.get('candidates', []):
            raise ValueError('Override target/distribution is not allowed by operator policy')
        if override.get('use') not in ('build', 'runtime', 'both'):
            raise ValueError('Override use must be build, runtime or both')
        ref, files = source(override['distribution'])
        entry = dict(files[safe_path(override['path'])])
        if entry['sha256'] != override['sha256'] or not entry['path'].endswith('.' + TARGETS[target][0]):
            raise ValueError('Override checksum/type does not match the candidate publication')
        for key in ('package', 'version', 'architecture'):
            if not isinstance(override.get(key), str) or not override[key]:
                raise ValueError('Override requires an exact package identity')
        targets[target]['overrides'].append({**entry, 'url': ref['base_url'] + quote(entry['path'], safe='/'),
                                             'source': ref, 'identity': {k: override[k] for k in
                                                 ('package', 'version', 'architecture')}, 'use': override['use']})
    return {'schema': SCHEMA, 'release': release, 'base': base, 'content_origin': origin(content_origin),
            'policy_sha256': hashlib.sha256(json.dumps(policy, sort_keys=True).encode()).hexdigest(),
            'targets': targets}


def identity(path, kind):
    if kind == 'deb':
        args = ['dpkg-deb', '--show', '--showformat=${Package}\t${Version}\t${Architecture}', str(path)]
    else:
        args = ['rpm', '-qp', '--qf', '%{NAME}\t%{EPOCHNUM}:%{VERSION}-%{RELEASE}\t%{ARCH}', str(path)]
    fields = subprocess.check_output(args, text=True).strip().split('\t')
    if len(fields) != 3 or not all(fields):
        raise ValueError('Cannot read package identity')
    return dict(zip(('package', 'version', 'architecture'), fields))


def key(info):
    # One target architecture per tree; an all/noarch package replaces the same
    # name built for amd64/x86_64 and vice versa.
    return info['package']


def newer(left, right, kind):
    if kind == 'deb':
        result = subprocess.run(['dpkg', '--compare-versions', left, 'gt', right])
        if result.returncode not in (0, 1):
            raise ValueError('Invalid Debian version')
        return result.returncode == 0
    import rpm
    def evr(value):
        epoch, tail = value.split(':', 1)
        version, release = tail.rsplit('-', 1)
        return epoch, version, release
    return rpm.labelCompare(evr(left), evr(right)) > 0


def download(entry, destination, allowed_origin):
    p = urlsplit(entry['url'])
    if (p.scheme + '://' + p.netloc != origin(allowed_origin) or p.query or p.fragment
            or not p.path.startswith('/pulp/content/') or p.username or p.password):
        raise ValueError('Locked download URL escaped the approved content origin')
    temporary = destination.with_suffix(destination.suffix + '.part')
    try:
        with requests.get(entry['url'], stream=True, timeout=(15, 300), allow_redirects=False) as response:
            if response.status_code != 200:
                raise RuntimeError(f'Dependency download failed with HTTP {response.status_code}')
            size = 0
            sha = hashlib.sha256()
            with temporary.open('wb') as output:
                for chunk in response.iter_content(1024 * 1024):
                    size += len(chunk)
                    if size > entry['size']:
                        raise ValueError('Dependency exceeds locked size')
                    sha.update(chunk)
                    output.write(chunk)
        if size != entry['size'] or sha.hexdigest() != entry['sha256']:
            raise ValueError('Dependency changed since locking; refusing unverified bytes')
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def fetch(lock, output, built=None):
    if lock.get('schema') != SCHEMA or not set(lock['targets']) <= set(TARGETS):
        raise ValueError('Unsupported lock schema or target')
    output = Path(output)
    if output.exists() and any(output.iterdir()):
        raise ValueError('Dependency output must be empty; do not mix snapshots')
    report = {}
    for target, selection in lock['targets'].items():
        kind, arch = TARGETS[target]
        destination = output / target
        destination.mkdir(parents=True, exist_ok=True)
        built_keys = set()
        for path in sorted((Path(built) / target).glob('*.' + kind)) if built else []:
            info = identity(path, kind)
            if info['architecture'] not in (arch, 'all' if kind == 'deb' else 'noarch', 'src'):
                raise ValueError('Build artifact architecture does not match its target')
            if info['architecture'] != 'src':
                built_keys.add(key(info))
            if info['package'] == 'packetfence' and not re.match(
                    r'^(?:\d+:)?' + re.escape(lock['release']) + r'(?:\.|[+~_-])', info['version']):
                raise ValueError('Built PacketFence version does not match the dependency lock')
        if built and 'packetfence' not in built_keys:
            raise ValueError('Missing PacketFence build for locked target ' + target)
        # Inspect real package metadata, not filenames. Download by checksum so
        # two directories/versions with the same basename cannot overwrite one another.
        rows = []
        for entry in selection['packages'] + selection['overrides']:
            path = destination / (entry['sha256'] + '.' + kind)
            if not path.exists():
                download(entry, path, lock['content_origin'])
            info = identity(path, kind)
            if info['architecture'] not in (arch, 'all' if kind == 'deb' else 'noarch'):
                raise ValueError('Dependency architecture does not match its target')
            if entry.get('identity') and entry['identity'] != info:
                raise ValueError('Override package identity does not match its declaration')
            rows.append((entry, path, info))
        overrides = {}
        for entry, path, info in rows:
            if 'identity' in entry:
                if key(info) in overrides or key(info) in built_keys:
                    raise ValueError('Duplicate override or override conflicts with pipeline build')
                overrides[key(info)] = entry['sha256']
        keep = {}
        for entry, path, info in rows:
            if key(info) in built_keys or (key(info) in overrides and overrides[key(info)] != entry['sha256']):
                continue
            # reprepro publishes one version per identity. Compare versions with
            # the native package manager, including Debian/RPM epochs.
            if key(info) in keep and keep[key(info)]['sha256'] != entry['sha256']:
                previous = keep[key(info)]['identity']
                if info['version'] == previous['version'] or info['architecture'] != previous['architecture']:
                    raise ValueError('Conflicting dependency identity: ' + info['package'])
                if not newer(info['version'], previous['version'], kind):
                    continue
            keep[key(info)] = {'sha256': entry['sha256'], 'identity': info, 'file': path.name,
                               'use': entry.get('use', 'base')}
        selected_files = {row['file'] for row in keep.values()}
        for path in destination.iterdir():
            if path.name not in selected_files:
                path.unlink()
        report[target] = list(keep.values())
    write_json(output / 'selection.json', report)
    return report


def list_files(client, version):
    result, offset = {}, 0
    while True:
        page = client.request('GET', API + 'content/file/files/',
                              params={'repository_version': version, 'limit': 1000, 'offset': offset})
        for item in page['results']:
            path = safe_path(item['relative_path'])
            if path in result:
                raise ValueError('Destination contains duplicate relative paths')
            result[path] = item
        offset += len(page['results'])
        if offset >= page['count']:
            return result
        if not page['results']:
            raise RuntimeError('Incomplete content pagination')


def resource(response, prefix):
    hrefs = set(response.get('created_resources', []))
    hrefs.add(response.get('pulp_href', ''))
    hrefs.add((response.get('result') or {}).get('pulp_href', ''))
    matches = [h for h in hrefs if h.startswith(API + prefix + '/')]
    if len(matches) != 1:
        raise RuntimeError('Expected one Pulp resource: ' + prefix)
    return matches[0]


def publish_tree(client, name, pipeline, tree, *, dependencies=False, apply=False):
    if not re.fullmatch(r'[1-9][0-9]*', str(pipeline)):
        raise ValueError('Pipeline ID must be a positive integer')
    prefix = str(pipeline) + ('/dependencies/' if dependencies else '/')
    repo = client.find('repositories/file/file', name)
    dist = client.find('distributions/file/file', name)
    if (repo.get('pulp_labels', {}).get('akainverse_ci_append_only') != 'true'
            or repo.get('autopublish') or dist.get('content_guard') or dist.get('repository')
            or not dist.get('publication')
            or dist.get('base_path') != 'files/' + name):
        raise ValueError('Destination must be an explicitly provisioned public CI file repository')
    initial = repo['latest_version_href']
    current_files = list_files(client, initial)
    tree = Path(tree)
    if not tree.is_dir() or tree.is_symlink():
        raise ValueError('Missing or symlinked repository tree')
    paths = sorted(tree.rglob('*'))
    if any(p.is_symlink() or not (p.is_file() or p.is_dir()) for p in paths):
        raise ValueError('Repository tree must contain only regular files/directories')
    required = ('GPG_PUBLIC_KEY', 'pipeline-lock.json')
    if any(not (tree / path).is_file() for path in required):
        raise ValueError('Repository tree must include its signing public key and dependency lock')
    inventory, additions = [], []
    for path in paths:
        if not path.is_file():
            continue
        relative = safe_path(path.relative_to(tree).as_posix())
        if any(p in ('conf', 'db', '.git') for p in PurePosixPath(relative).parts) or relative == 'PULP_MANIFEST':
            raise ValueError('Refusing repository internals or a caller-supplied PULP_MANIFEST')
        full = prefix + relative
        sha = digest(path)
        row = {'path': full, 'sha256': sha, 'size': path.stat().st_size}
        inventory.append(row)
        if full in current_files:
            if current_files[full]['sha256'] != sha:
                raise ValueError('Existing pipeline path has a different hash: ' + full)
        else:
            additions.append((path, row))
    result = {'repository': name, 'pipeline': str(pipeline), 'prefix': prefix,
              'previous_publication': dist.get('publication'), 'files': inventory,
              'new_files': len(additions), 'applied': False}
    if not apply:
        return result
    version = initial
    for path, row in additions:
        if client.request('GET', repo['pulp_href'])['latest_version_href'] != version:
            raise RuntimeError('Repository changed during upload; serialize publishers and review')
        uploaded = client.upload(API + 'content/file/files/', path, {'relative_path': row['path'],
                                                                   'sha256': row['sha256'],
                                                                   'repository': repo['pulp_href']})
        href = resource(uploaded, 'content/file/files')
        obj = client.request('GET', href)
        if obj['relative_path'] != row['path'] or obj['sha256'] != row['sha256']:
            raise RuntimeError('Uploaded content does not match the local file')
        # Attach on upload so a scoped publisher can retrieve its own content.
        # The public distribution still serves its previous publication.
        version = client.request('GET', repo['pulp_href'])['latest_version_href']
    # Verify the entire resulting membership: preserve everything that was there.
    actual = list_files(client, version)
    expected = {p: f['sha256'] for p, f in current_files.items()}
    expected.update({f['path']: f['sha256'] for f in inventory})
    if {p: f['sha256'] for p, f in actual.items()} != expected:
        raise RuntimeError('Unexpected repository membership; distribution remains unchanged')
    response = client.wait(client.request('POST', API + 'publications/file/file/',
                                          json={'repository_version': version}))
    publication = resource(response, 'publications/file/file')
    if client.request('GET', publication)['repository_version'] != version:
        raise RuntimeError('Publication does not match the verified repository version')
    current = client.request('GET', dist['pulp_href'])
    if (any(current.get(k) != dist.get(k) for k in ('publication', 'content_guard', 'repository', 'base_path'))
            or client.request('GET', repo['pulp_href'])['latest_version_href'] != version):
        raise RuntimeError('Distribution/repository changed; serialize publishers and review')
    client.wait(client.request('PATCH', dist['pulp_href'], json={'publication': publication}))
    result.update(applied=True, repository_version=version, publication=publication)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    lock = sub.add_parser('lock')
    lock.add_argument('--policy', type=Path, required=True)
    lock.add_argument('--release', required=True)
    lock.add_argument('--base', required=True)
    lock.add_argument('--overrides', type=Path)
    lock.add_argument('--output', type=Path, required=True)
    fetcher = sub.add_parser('fetch')
    fetcher.add_argument('--lock', type=Path, required=True)
    fetcher.add_argument('--output', type=Path, required=True)
    fetcher.add_argument('--built', type=Path)
    publisher = sub.add_parser('publish')
    publisher.add_argument('--repository', required=True)
    publisher.add_argument('--pipeline', required=True)
    publisher.add_argument('--tree', type=Path, required=True)
    publisher.add_argument('--dependencies', action='store_true')
    publisher.add_argument('--apply', action='store_true')
    publisher.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == 'fetch':
            fetch(json.loads(args.lock.read_text()), args.output, args.built)
        else:
            client = Pulp(os.environ['PULP_URL'], os.environ['PULP_USERNAME'], os.environ['PULP_PASSWORD'])
            if args.command == 'lock':
                result = resolve(client, json.loads(args.policy.read_text()), args.release, args.base,
                                 os.environ['PULP_CONTENT_ORIGIN'],
                                 json.loads(args.overrides.read_text()) if args.overrides else None)
            else:
                result = publish_tree(client, args.repository, args.pipeline, args.tree,
                                      dependencies=args.dependencies, apply=args.apply)
            write_json(args.output, result)
    except (KeyError, ValueError, RuntimeError, OSError, subprocess.CalledProcessError, requests.RequestException) as exc:
        print(f'Pipeline repository failed: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
