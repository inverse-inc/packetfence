#!/usr/bin/env python3
"""Lock public dependency snapshots and append immutable, pre-signed CI trees.

The generator (PacketFence's generate-pages.sh) owns APT/RPM metadata. This
transport deliberately uses pulp_file, so .dsc/SRPMs and signed bytes survive.
Pipeline appends (publish) may run concurrently; tree merges (merge-apt) must be serialized.
"""
import argparse
from concurrent.futures import FIRST_EXCEPTION, ThreadPoolExecutor, wait
import csv
from datetime import datetime, timezone
import gzip
import hashlib
import json
import os
import re
import subprocess
import sys
import threading
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


def upload_workers():
    value = os.environ.get('PULP_UPLOAD_WORKERS', '4')
    if not re.fullmatch(r'[0-9]+', value) or not 1 <= int(value) <= 16:
        raise ValueError('PULP_UPLOAD_WORKERS must be between 1 and 16')
    return int(value)


def upload_files(client, repo, files, workers=None):
    """Upload {relative_path: (local file, sha256)} into repo, several at a time.

    Non-admin uploads must name the repository, so each one adds a single file;
    Pulp serializes those additions per repository.
    """
    local = threading.local()

    def one(path, source, sha):
        worker = getattr(local, 'client', None)
        if worker is None:
            worker = local.client = client.clone() if hasattr(client, 'clone') else client
        uploaded = worker.upload(API + 'content/file/files/', Path(source),
                                 {'relative_path': path, 'sha256': sha, 'repository': repo['pulp_href']})
        obj = worker.request('GET', resource(uploaded, 'content/file/files'))
        if obj['relative_path'] != path or obj['sha256'] != sha:
            raise RuntimeError('Uploaded content does not match the local file: ' + path)

    with ThreadPoolExecutor(max_workers=workers or upload_workers()) as pool:
        futures = [pool.submit(one, path, source, sha) for path, (source, sha) in sorted(files.items())]
        done, _ = wait(futures, return_when=FIRST_EXCEPTION)
        failed = [f for f in done if f.exception()]
        if failed:
            for future in futures:
                future.cancel()
            raise failed[0].exception()


def publish_latest(client, repo, dist, attempts=10):
    """Serve a publication of the repository's latest version.

    Concurrent appenders each end here, so whoever finishes last serves every addition;
    a slower job never puts back an older version.
    """
    for _ in range(attempts):
        latest = client.request('GET', repo['pulp_href'])['latest_version_href']
        current = client.request('GET', dist['pulp_href'])
        if any(current.get(k) != dist.get(k) for k in ('content_guard', 'repository', 'base_path')):
            raise RuntimeError('Distribution changed; review before publishing')
        served = current.get('publication')
        if served and client.request('GET', served)['repository_version'] == latest:
            return served, latest
        response = client.wait(client.request('POST', API + 'publications/file/file/',
                                              json={'repository_version': latest}))
        publication = resource(response, 'publications/file/file')
        if client.request('GET', publication)['repository_version'] != latest:
            raise RuntimeError('Publication does not match the requested repository version')
        client.wait(client.request('PATCH', dist['pulp_href'], json={'publication': publication}))
    raise RuntimeError('Repository kept changing; the distribution may lag, retry the job')


def check_pipeline_files(client, version, prefix, expected):
    mine = {p: f['sha256'] for p, f in list_files(client, version).items() if p.startswith(prefix)}
    if mine != expected:
        raise RuntimeError(f'Unexpected content under {prefix} in {version}; review before trusting it')


def publish_tree(client, name, pipeline, tree, *, dependencies=False, apply=False, require_lock=True):
    if not re.fullmatch(r'[1-9][0-9]*', str(pipeline)):
        raise ValueError('Pipeline ID must be a positive integer')
    prefix = str(pipeline) + ('/dependencies/' if dependencies else '/')
    repo = client.find('repositories/file/file', name)
    dist = client.find('distributions/file/file', name)
    labels = repo.get('pulp_labels', {})
    # Restored hosts label managed file snapshots akainverse_download_snapshot; RBAC limits the writer.
    if (not (labels.get('akainverse_ci_append_only') == 'true' or labels.get('akainverse_download_snapshot') == 'true')
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
    required = ('GPG_PUBLIC_KEY', 'pipeline-lock.json') if require_lock else ('GPG_PUBLIC_KEY',)
    if any(not (tree / path).is_file() for path in required):
        raise ValueError('Repository tree must include its signing public key'
                         + (' and dependency lock' if require_lock else ''))
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
    # Other pipelines may append concurrently: verify only this pipeline's paths.
    expected = {p: f['sha256'] for p, f in current_files.items() if p.startswith(prefix)}
    expected.update({f['path']: f['sha256'] for f in inventory})
    upload_files(client, repo, {row['path']: (path, row['sha256']) for path, row in additions})
    check_pipeline_files(client, client.request('GET', repo['pulp_href'])['latest_version_href'],
                         prefix, expected)
    publication, version = publish_latest(client, repo, dist)
    check_pipeline_files(client, version, prefix, expected)
    result.update(applied=True, repository_version=version, publication=publication)
    return result


def switch_publication(client, repo, dist, version):
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
    return publication


# --- debian/X.Y and debian-branches/X.Y file trees: merge one signed CI build (newest wins) ---

APT_TREE_REPO = re.compile(r'debian(-branches)?-[0-9]+-[0-9]+')
SIGNED_FILES = ('Release', 'InRelease', 'Release.gpg')
RELEASE_KEYS = ('Origin', 'Label', 'Suite', 'Codename', 'Architectures', 'Components', 'Description')


def parse_stanzas(text):
    """Deb822 paragraphs as ordered [field, value] lists; continuation lines stay in the value."""
    stanzas = []
    for block in re.split(r'\n[ \t]*\n', text.strip()):
        fields = []
        for line in block.splitlines():
            if line[:1] in (' ', '\t') and fields:
                fields[-1][1] += '\n' + line
            elif line.strip():
                name, _, value = line.partition(':')
                fields.append([name, value.strip()])
        if fields:
            stanzas.append(fields)
    return stanzas


def field(stanza, name):
    return next((value for key, value in stanza if key.lower() == name.lower()), None)


def render_stanzas(stanzas):
    return ''.join('\n'.join(f'{k}: {v}' if v else f'{k}:' for k, v in s) + '\n\n' for s in stanzas)


def read_index(directory, name):
    """A generated Packages/Sources index, plain or gzip."""
    if (directory / name).is_file():
        return (directory / name).read_text()
    if (directory / (name + '.gz')).is_file():
        return gzip.decompress((directory / (name + '.gz')).read_bytes()).decode()
    return ''


def component_release(fields, component, arch):
    return (f'Archive: {fields.get("Suite", fields["Codename"])}\nComponent: {component}\nOrigin: {fields.get("Origin", "")}\n'
            f'Label: {fields.get("Label", "")}\nArchitecture: {arch}\n').encode()


def merge_apt_tree(client, name, tree, content_url, *, codename='bookworm', sign=None, work=None, apply=False):
    """Add one pipeline's packages to a debian(-branches)-X-Y file tree; the newest build of each name wins.

    tree is the generated PPA debian/ directory (dists/<codename>/main, pool/main). The
    destination keeps the reprepro layout: component <codename>, pool/<codename>/...
    """
    if not APT_TREE_REPO.fullmatch(name):
        raise ValueError('Destination must be a debian-X-Y or debian-branches-X-Y file repository')
    repo = client.find('repositories/file/file', name)
    dist = client.find('distributions/file/file', name)
    if (repo.get('autopublish') or dist.get('content_guard') or dist.get('repository')
            or not dist.get('publication') or dist.get('base_path') != 'files/' + name):
        raise ValueError('Destination must be a published public APT file repository')
    tree, content_url = Path(tree), content_url.rstrip('/')
    if not content_url.startswith('https://'):
        raise ValueError('Content URL must be HTTPS')
    generated = tree / 'dists' / codename / 'main'
    if not generated.is_dir():
        raise ValueError(f'Missing generated dists/{codename}/main in the tree')
    initial = repo['latest_version_href']
    current = list_files(client, initial)
    base = f'dists/{codename}'

    def remote(path):
        return read_public(f'{content_url}/{path}') if path in current else b''

    def remap(path):
        path = path.rstrip('/')
        if not path.startswith('pool/main/'):
            raise ValueError('Generated pool path outside pool/main: ' + path)
        return safe_path(f'pool/{codename}/' + path[len('pool/main/'):])

    # Header fields come from the live Release so clients keep the same origin/suite pins.
    live = parse_stanzas(remote(base + '/Release').decode())
    fields = {k: v for k, v in (live[0] if live else []) if k in RELEASE_KEYS}
    # A new (empty) tree gets the same header as the existing reprepro trees.
    fields.setdefault('Origin', f'Inverse {codename} distribution')
    fields.setdefault('Label', f'Inverse {codename} distribution')
    fields.setdefault('Codename', codename)
    fields.setdefault('Architectures', 'i386 amd64')
    fields.setdefault('Components', codename)
    fields.setdefault('Description', 'Inverse Debian distribution')
    component = fields['Components'].split()[0]
    if component != codename:
        raise ValueError('Expected the reprepro component to equal the codename')
    archs = fields['Architectures'].split()

    uploads = {}  # destination path -> local file
    new_bin = []
    for stanza in parse_stanzas(read_index(generated / 'binary-amd64', 'Packages')):
        original = field(stanza, 'Filename')
        local = tree / safe_path(original)
        if not local.is_file() or digest(local) != field(stanza, 'SHA256'):
            raise ValueError('Generated index does not match its pool file: ' + original)
        target = remap(original)
        uploads[target] = local
        new_bin.append([[k, target if k == 'Filename' else v] for k, v in stanza])
    if not new_bin:
        raise ValueError('The generated tree has no binary packages')
    names = {field(s, 'Package') for s in new_bin}

    regenerated = {}
    for arch in (a for a in archs if a != 'source'):
        path = f'{base}/{component}/binary-{arch}/Packages'
        kept = [s for s in parse_stanzas(remote(path).decode()) if field(s, 'Package') not in names]
        text = render_stanzas(kept + [s for s in new_bin if field(s, 'Architecture') in (arch, 'all')]).encode()
        regenerated[path] = text
        regenerated[path + '.gz'] = gzip.compress(text, mtime=0)
        regenerated[f'{base}/{component}/binary-{arch}/Release'] = component_release(fields, component, arch)

    if 'source' in archs:
        new_src = []
        for stanza in parse_stanzas(read_index(generated / 'source', 'Sources')):
            directory = field(stanza, 'Directory')
            target_dir = remap(directory)
            for line in (field(stanza, 'Checksums-Sha256') or '').splitlines():
                parts = line.split()
                if len(parts) != 3:
                    continue
                local = tree / safe_path(f'{directory}/{parts[2]}')
                if not local.is_file() or digest(local) != parts[0]:
                    raise ValueError('Generated Sources does not match its pool file: ' + parts[2])
                uploads[f'{target_dir}/{parts[2]}'] = local
            new_src.append([[k, target_dir if k == 'Directory' else v] for k, v in stanza])
        path = f'{base}/{component}/source/Sources.gz'
        replaced = {field(s, 'Package') for s in new_src}
        old_text = gzip.decompress(remote(path)).decode() if path in current else ''
        kept = [s for s in parse_stanzas(old_text) if field(s, 'Package') not in replaced]
        regenerated[path] = gzip.compress(render_stanzas(kept + new_src).encode(), mtime=0)
        regenerated[f'{base}/{component}/source/Release'] = component_release(fields, component, 'source')

    # Any other live index under dists/ (e.g. debian-installer) is carried over unchanged.
    indexed = dict(regenerated)
    for path in current:
        if path.startswith(base + '/') and path not in indexed and path[len(base) + 1:] not in SIGNED_FILES:
            indexed[path] = remote(path)

    lines = [f'{k}: {fields[k]}' for k in ('Origin', 'Label', 'Suite', 'Codename') if k in fields]
    lines.append('Date: ' + datetime.now(timezone.utc).strftime('%a, %d %b %Y %H:%M:%S UTC'))
    lines += [f'{k}: {fields[k]}' for k in ('Architectures', 'Components', 'Description') if k in fields]
    for title, algorithm in (('MD5Sum', 'md5'), ('SHA1', 'sha1'), ('SHA256', 'sha256')):
        lines.append(title + ':')
        lines += [f' {hashlib.new(algorithm, indexed[p]).hexdigest()} {len(indexed[p]):>16} {p[len(base) + 1:]}'
                  for p in sorted(indexed)]
    regenerated[base + '/Release'] = ('\n'.join(lines) + '\n').encode()

    conflicts = [p for p, f in uploads.items() if p in current and current[p]['sha256'] != digest(f)]
    if conflicts:
        raise ValueError('Existing pool path has a different hash: ' + conflicts[0])
    result = {'repository': name, 'packages': sorted(names), 'previous_publication': dist.get('publication'),
              'new_pool_files': sorted(p for p in uploads if p not in current),
              'indexes': sorted(regenerated), 'applied': False}
    if not apply:
        return result
    if sign is None or work is None:
        raise ValueError('Applying needs a signer and a work directory')

    work = Path(work)
    for path, data in regenerated.items():
        (work / path).parent.mkdir(parents=True, exist_ok=True)
        (work / path).write_bytes(data)
    sign(work / base / 'Release', work / base / 'InRelease', work / base / 'Release.gpg')
    files = {p: f for p, f in uploads.items() if p not in current}
    files.update({p: work / p for p in [*regenerated, base + '/InRelease', base + '/Release.gpg']})
    result.update(apply_merge(client, repo, dist, initial, current, files))
    return result


def apply_merge(client, repo, dist, initial, current, files):
    """Upload a merged tree's changed files, verify the exact membership, then switch."""
    expected = {p: f['sha256'] for p, f in current.items()}
    changed = {}
    for path, source in files.items():
        expected[path] = sha = digest(source)
        if not (path in current and current[path]['sha256'] == sha):
            changed[path] = (source, sha)
    # A merge rewrites shared indexes: refuse to interleave with another writer.
    if client.request('GET', repo['pulp_href'])['latest_version_href'] != initial:
        raise RuntimeError('Repository changed before upload; serialize publishers and review')
    # Clients keep the old publication until the switch, so upload order does not matter.
    upload_files(client, repo, changed)
    version = client.request('GET', repo['pulp_href'])['latest_version_href']
    if {p: f['sha256'] for p, f in list_files(client, version).items()} != expected:
        raise RuntimeError('Unexpected repository membership; distribution remains unchanged')
    publication = switch_publication(client, repo, dist, version)
    return {'applied': True, 'repository_version': version, 'publication': publication}


# --- RHEL8/branches/X.Y file trees: merge one signed CI build (newest wins) ---

RPM_TREE_REPO = re.compile(r'rhel8-branches-[0-9]+-[0-9]+')
RPM_METADATA = {'primary': 'metadata', 'filelists': 'filelists', 'other': 'otherdata'}
PACKAGE_BLOCK = re.compile(r'<package\b.*?</package>', re.S)
# createrepo output is matched textually (as the APT side), never fed to an XML parser.
REPOMD_DATA = re.compile(r'<data type="([a-z_]+)">(.*?)</data>', re.S)


def rpm_metadata(repomd, read):
    """{type: xml text} of primary/filelists/other, each checked against repomd's sha256."""
    out = {}
    for kind, body in REPOMD_DATA.findall(repomd.decode()):
        if kind not in RPM_METADATA:
            continue
        checksum = rpm_field(body, r'<checksum type="sha256">([0-9a-f]{64})</checksum>', 'a sha256 checksum')
        raw = read(safe_path(rpm_field(body, r'<location href="([^"]+)"/>', 'a location')))
        if hashlib.sha256(raw).hexdigest() != checksum:
            raise ValueError(f'{kind} metadata does not match repomd.xml')
        out[kind] = gzip.decompress(raw).decode() if raw[:2] == b'\x1f\x8b' else raw.decode()
    if set(out) != set(RPM_METADATA):
        raise ValueError('repomd.xml must list primary, filelists and other')
    return out


def rpm_root(xml, kind):
    """Root element attributes without the packages count."""
    match = re.search(rf'<{RPM_METADATA[kind]}\b([^>]*?)/?>', xml)
    if not match:
        raise ValueError(f'Unexpected {kind} metadata')
    return re.sub(r'\s+packages="[0-9]*"', '', match.group(1))


def rpm_field(block, pattern, what):
    match = re.search(pattern, block)
    if not match:
        raise ValueError('RPM metadata entry without ' + what)
    return match.group(1)


def render_rpm_metadata(kind, attributes, blocks):
    root = RPM_METADATA[kind]
    return (f'<?xml version="1.0" encoding="UTF-8"?>\n<{root}{attributes} packages="{len(blocks)}">\n'
            + ''.join(b + '\n' for b in blocks) + f'</{root}>\n').encode()


def render_repomd(files, now):
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<repomd xmlns="http://linux.duke.edu/metadata/repo" xmlns:rpm="http://linux.duke.edu/metadata/rpm">',
             f'  <revision>{now}</revision>']
    for kind, data in files.items():
        packed = gzip.compress(data, mtime=0)
        lines += [f'  <data type="{kind}">',
                  f'    <checksum type="sha256">{hashlib.sha256(packed).hexdigest()}</checksum>',
                  f'    <open-checksum type="sha256">{hashlib.sha256(data).hexdigest()}</open-checksum>',
                  f'    <location href="repodata/{kind}.xml.gz"/>',
                  f'    <timestamp>{now}</timestamp>',
                  f'    <size>{len(packed)}</size>',
                  f'    <open-size>{len(data)}</open-size>',
                  '  </data>']
    return ('\n'.join(lines + ['</repomd>']) + '\n').encode()


def merge_rpm_tree(client, name, tree, content_url, *, sign=None, work=None, apply=False, now=None):
    """Add one pipeline's RPMs to a rhel8-branches-X-Y file tree; the newest build of each name wins.

    tree is the generated x86_64 directory (*.rpm, repodata/). The destination keeps the
    release-tree layout: x86_64/RPMS/<file> and x86_64/repodata/{primary,filelists,other}.xml.gz.
    """
    if not RPM_TREE_REPO.fullmatch(name):
        raise ValueError('Destination must be a rhel8-branches-X-Y file repository')
    repo = client.find('repositories/file/file', name)
    dist = client.find('distributions/file/file', name)
    if (repo.get('autopublish') or dist.get('content_guard') or dist.get('repository')
            or not dist.get('publication') or dist.get('base_path') != 'files/' + name):
        raise ValueError('Destination must be a published public RPM file repository')
    tree, content_url = Path(tree), content_url.rstrip('/')
    if not content_url.startswith('https://'):
        raise ValueError('Content URL must be HTTPS')
    if not (tree / 'repodata' / 'repomd.xml').is_file():
        raise ValueError('Missing generated repodata/repomd.xml in the tree')
    initial = repo['latest_version_href']
    current = list_files(client, initial)

    def remote(path):
        data = read_public(f'{content_url}/x86_64/{path}')
        if current.get('x86_64/' + path, {}).get('sha256') != hashlib.sha256(data).hexdigest():
            raise RuntimeError('Served tree differs from the repository; publish or review it first: ' + path)
        return data

    generated = rpm_metadata((tree / 'repodata' / 'repomd.xml').read_bytes(), lambda p: (tree / p).read_bytes())
    live = rpm_metadata(remote('repodata/repomd.xml'), remote) if 'x86_64/repodata/repomd.xml' in current else None

    uploads, new_ids, names = {}, set(), set()
    new_primary = []
    for block in PACKAGE_BLOCK.findall(generated['primary']):
        pkgid = rpm_field(block, r'<checksum type="sha256" pkgid="YES">([0-9a-f]{64})</checksum>', 'sha256 pkgid')
        href = rpm_field(block, r'<location href="([^"/]+\.rpm)"/>', 'a flat location')
        local = tree / safe_path(href)
        if not local.is_file() or digest(local) != pkgid:
            raise ValueError('Generated metadata does not match its RPM: ' + href)
        uploads['x86_64/RPMS/' + href] = local
        new_ids.add(pkgid)
        names.add(rpm_field(block, r'<name>([^<]+)</name>', 'a name'))
        new_primary.append(block.replace(f'<location href="{href}"/>', f'<location href="RPMS/{href}"/>'))
    if not new_primary:
        raise ValueError('The generated tree has no RPM packages')

    kept_primary, kept_ids = [], set()
    for block in PACKAGE_BLOCK.findall(live['primary']) if live else []:
        if rpm_field(block, r'<name>([^<]+)</name>', 'a name') in names:
            continue
        pkgid = rpm_field(block, r'<checksum type="sha256" pkgid="YES">([0-9a-f]{64})</checksum>', 'sha256 pkgid')
        href = rpm_field(block, r'<location href="([^"]+)"/>', 'a location')
        if current.get('x86_64/' + safe_path(href), {}).get('sha256') != pkgid:
            raise ValueError('Live metadata references a missing or different RPM: ' + href)
        kept_primary.append(block)
        kept_ids.add(pkgid)

    merged = {'primary': render_rpm_metadata('primary', rpm_root((live or generated)['primary'], 'primary'),
                                             kept_primary + new_primary)}
    for kind in ('filelists', 'other'):
        def keep(blocks, ids):
            return [b for b in PACKAGE_BLOCK.findall(blocks) if rpm_field(b, r'pkgid="([0-9a-f]{64})"', 'a pkgid') in ids]
        merged[kind] = render_rpm_metadata(kind, rpm_root((live or generated)[kind], kind),
                                           (keep(live[kind], kept_ids) if live else []) + keep(generated[kind], new_ids))
    conflicts = [p for p, f in uploads.items() if p in current and current[p]['sha256'] != digest(f)]
    if conflicts:
        raise ValueError('Existing RPM path has a different hash: ' + conflicts[0])
    result = {'repository': name, 'packages': sorted(names), 'previous_publication': dist.get('publication'),
              'new_rpms': sorted(p for p in uploads if p not in current), 'applied': False}
    if not apply:
        return result
    if sign is None or work is None:
        raise ValueError('Applying needs a signer and a work directory')

    regenerated = {f'x86_64/repodata/{kind}.xml.gz': gzip.compress(data, mtime=0) for kind, data in merged.items()}
    regenerated['x86_64/repodata/repomd.xml'] = render_repomd(merged, int(now or datetime.now(timezone.utc).timestamp()))
    work = Path(work)
    for path, data in regenerated.items():
        (work / path).parent.mkdir(parents=True, exist_ok=True)
        (work / path).write_bytes(data)
    sign(work / 'x86_64/repodata/repomd.xml', work / 'x86_64/repodata/repomd.xml.asc')
    files = {p: f for p, f in uploads.items() if p not in current}
    files.update({p: work / p for p in [*regenerated, 'x86_64/repodata/repomd.xml.asc']})
    result.update(apply_merge(client, repo, dist, initial, current, files))
    return result


def gpg_signer(fingerprint):
    if not re.fullmatch(r'[A-F0-9]{40}', fingerprint or ''):
        raise ValueError('Set GPG_KEY_FINGERPRINT to the exact 40-hex signing fingerprint')

    def sign(release, inrelease, detached):
        base = ['gpg', '--batch', '--yes', '--pinentry-mode', 'loopback', '--local-user', fingerprint,
                '--digest-algo', 'SHA512']
        subprocess.run(base + ['--clearsign', '--output', str(inrelease), str(release)], check=True)
        subprocess.run(base + ['--armor', '--detach-sign', '--output', str(detached), str(release)], check=True)
    return sign


def gpg_detached_signer(fingerprint):
    """Armored detached signature (repomd.xml.asc) with the same approved key."""
    if not re.fullmatch(r'[A-F0-9]{40}', fingerprint or ''):
        raise ValueError('Set GPG_KEY_FINGERPRINT to the exact 40-hex signing fingerprint')

    def sign(path, detached):
        subprocess.run(['gpg', '--batch', '--yes', '--pinentry-mode', 'loopback', '--local-user', fingerprint,
                        '--digest-algo', 'SHA512', '--armor', '--detach-sign', '--output', str(detached), str(path)],
                       check=True)
    return sign


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
    publisher.add_argument('--no-lock', action='store_true',
                           help='Publish a PacketFence-only tree without a dependency lock')
    publisher.add_argument('--apply', action='store_true')
    publisher.add_argument('--output', type=Path, required=True)
    branch = sub.add_parser('merge-apt', help='Merge a generated debian/ tree into debian(-branches)-X-Y')
    branch.add_argument('--repository', required=True)
    branch.add_argument('--tree', type=Path, required=True, help='Generated PPA debian/ directory')
    branch.add_argument('--content-url', required=True, help='Public HTTPS URL of the destination tree')
    branch.add_argument('--codename', default='bookworm')
    branch.add_argument('--work', type=Path, required=True, help='Empty directory for signed metadata')
    branch.add_argument('--apply', action='store_true')
    branch.add_argument('--output', type=Path, required=True)
    rpm = sub.add_parser('merge-rpm', help='Merge a generated EL8 x86_64 tree into rhel8-branches-X-Y')
    rpm.add_argument('--repository', required=True)
    rpm.add_argument('--tree', type=Path, required=True, help='Generated PPA centos/8/x86_64 directory')
    rpm.add_argument('--content-url', required=True, help='Public HTTPS URL of the destination tree')
    rpm.add_argument('--work', type=Path, required=True, help='Empty directory for signed metadata')
    rpm.add_argument('--apply', action='store_true')
    rpm.add_argument('--output', type=Path, required=True)
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
            elif args.command == 'merge-apt':
                sign = gpg_signer(os.environ.get('GPG_KEY_FINGERPRINT')) if args.apply else None
                result = merge_apt_tree(client, args.repository, args.tree, args.content_url,
                                      codename=args.codename, sign=sign, work=args.work, apply=args.apply)
            elif args.command == 'merge-rpm':
                sign = gpg_detached_signer(os.environ.get('GPG_KEY_FINGERPRINT')) if args.apply else None
                result = merge_rpm_tree(client, args.repository, args.tree, args.content_url,
                                        sign=sign, work=args.work, apply=args.apply)
            else:
                result = publish_tree(client, args.repository, args.pipeline, args.tree,
                                      dependencies=args.dependencies, apply=args.apply,
                                      require_lock=not args.no_lock)
            write_json(args.output, result)
    except (KeyError, ValueError, RuntimeError, OSError, subprocess.CalledProcessError, requests.RequestException) as exc:
        print(f'Pipeline repository failed: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
