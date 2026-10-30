#!/usr/bin/env python3
"""Plan, push, fetch, or inspect package snapshots in a private S3 bucket.

Plan is offline. Push/fetch require --apply to transfer files. Credentials use
the normal AWS SDK environment/profile; no credentials are written to manifests.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import tempfile
from urllib.parse import urlsplit

SCHEMA = 'pulp-package-lake-v1'
UNIQUE_SCHEMA = 'pulp-package-lake-v2'
NAMED_SCHEMA = 'pulp-package-lake-v3'
CHUNK = 1024 * 1024
MAX_MANIFEST = 32 * 1024 * 1024


def digest_file(path):
    digest, size = hashlib.sha256(), 0
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(CHUNK), b''):
            digest.update(chunk)
            size += len(chunk)
    return digest.hexdigest(), size


def relative_path(value):
    path = PurePosixPath(value)
    if (not isinstance(value, str) or not value or value == '.' or path.is_absolute()
            or str(path) != value or any(p in ('.', '..') for p in path.parts)
            or '\\' in value or any(ord(c) < 32 for c in value)):
        raise ValueError('Invalid relative file path')
    return value


def identifier(value):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,159}', value):
        raise ValueError('Snapshot/release must be a simple name, without slashes')
    return value


def validate(manifest):
    if manifest.get('schema') not in (SCHEMA, UNIQUE_SCHEMA, NAMED_SCHEMA):
        raise ValueError('Unsupported package lake manifest')
    identifier(manifest['snapshot'])
    identifier(manifest['release'])
    if manifest['access'] not in ('public', 'private', 'mixed'):
        raise ValueError('Manifest must record the intended Pulp access level')
    seen, sizes = set(), {}
    if not manifest['files']:
        raise ValueError('Empty snapshots are not supported')
    for item in manifest['files']:
        if 'storage_id' in item and (manifest['schema'] not in (UNIQUE_SCHEMA, NAMED_SCHEMA) or
                                     not re.fullmatch(r'[a-f0-9]{64}', item['storage_id'])):
            raise ValueError('Invalid unique object storage identity')
        if 'object_path' in item:
            if manifest['schema'] != NAMED_SCHEMA or 'storage_id' in item:
                raise ValueError('Named objects require a version-3 manifest without storage_id')
            named_path(item['object_path'])
            if item['object_path'].split('/')[2] != item['sha256']:
                raise ValueError('Named object path does not match its checksum identity')
            if not isinstance(item.get('object_version'), str) or item['object_version'] in ('', 'null'):
                raise ValueError('Named objects require an exact S3 object version')
        path = relative_path(item['path'])
        if path in seen:
            raise ValueError('Duplicate path in manifest')
        seen.add(path)
        if (not re.fullmatch(r'[a-f0-9]{64}', item['sha256'])
                or type(item['size']) is not int or item['size'] < 0):
            raise ValueError('Invalid file checksum or size')
        if sizes.setdefault(item['sha256'], item['size']) != item['size']:
            raise ValueError('Conflicting sizes for one checksum')
    for path in seen:
        if any(str(parent) in seen for parent in PurePosixPath(path).parents):
            raise ValueError('Manifest file conflicts with a parent directory')
    return manifest


def encode(manifest):
    raw = (json.dumps(validate(manifest), sort_keys=True, separators=(',', ':')) + '\n').encode()
    if len(raw) > MAX_MANIFEST:
        raise ValueError('Manifest exceeds size limit; split the snapshot')
    return raw


def local_path(root, relative):
    root = root.resolve(strict=True)
    path = root
    for part in PurePosixPath(relative_path(relative)).parts:
        path = path / part
        if path.is_symlink():
            raise ValueError('Symlinks are not permitted in a snapshot tree')
    if not path.resolve().is_relative_to(root):
        raise ValueError('Path escaped the snapshot root')
    return path


def plan(root, snapshot, release, access):
    root = root.resolve(strict=True)
    files = []
    for directory, dirs, names in os.walk(root, followlinks=False):
        for name in dirs + names:
            if (Path(directory) / name).is_symlink():
                raise ValueError('Symlinks are not permitted in a snapshot tree')
        for name in sorted(names):
            path = Path(directory) / name
            if not path.is_file():
                raise ValueError('Snapshot entries must be regular files')
            digest, size = digest_file(path)
            files.append({'path': path.relative_to(root).as_posix(), 'sha256': digest, 'size': size})
    return validate({'schema': SCHEMA, 'snapshot': snapshot, 'release': release,
                     'access': access, 'files': sorted(files, key=lambda f: f['path'])})


def object_key(prefix, digest):
    return f'{prefix}/objects/sha256/{digest[:2]}/{digest[2:]}'


def payload_key(prefix, item):
    if 'object_path' in item:
        return prefix + '/' + named_path(item['object_path'])
    key = object_key(prefix, item['sha256'])
    if 'storage_id' in item:
        if not re.fullmatch(r'[a-f0-9]{64}', item['storage_id']):
            raise ValueError('Invalid unique object storage identity')
        key += '/' + item['storage_id']
    return key


def named_path(value):
    relative_path(value)
    parts = value.split('/')
    if (len(parts) != 5 or parts[0] not in ('packages', 'metadata') or parts[1] != parts[4]
            or not re.fullmatch('[a-f0-9]{64}', parts[2]) or not re.fullmatch('[a-f0-9]{32}', parts[3])):
        raise ValueError('Invalid named package object path')
    return value


def manifest_key(prefix, snapshot, digest):
    return f'{prefix}/manifests/{identifier(snapshot)}/{digest}.json'


def verify_object(client, bucket, key, digest, size, version=None):
    response = client.get_object(Bucket=bucket, Key=key, **({'VersionId': version} if version else {}))
    hashed, count = hashlib.sha256(), 0
    try:
        for chunk in iter(lambda: response['Body'].read(CHUNK), b''):
            hashed.update(chunk)
            count += len(chunk)
            if count > size:
                raise ValueError('Object exceeds its declared size')
    finally:
        response['Body'].close()
    if count != size or hashed.hexdigest() != digest:
        raise ValueError('Object failed SHA256/size verification')


def head(client, bucket, key):
    try:
        return client.head_object(Bucket=bucket, Key=key)
    except Exception as exc:
        # A denied HEAD is not proof that an object is absent.
        if getattr(exc, 'response', {}).get('Error', {}).get('Code') in ('404', 'NoSuchKey', 'NotFound'):
            return None
        raise


def push(client, bucket, prefix, manifest, root):
    if manifest.get('schema') in (UNIQUE_SCHEMA, NAMED_SCHEMA):
        raise ValueError('Version-2/3 snapshots require the corresponding sync/migration workflow')
    raw = encode(manifest)
    manifest_digest = hashlib.sha256(raw).hexdigest()
    uploaded, reused, seen = 0, 0, set()
    for item in manifest['files']:
        path = local_path(root, item['path'])
        # Validate even duplicate sources: the saved plan must still match disk.
        if digest_file(path) != (item['sha256'], item['size']):
            raise ValueError('Source changed since planning: ' + item['path'])
        digest = item['sha256']
        if digest in seen:
            continue
        seen.add(digest)
        key = object_key(prefix, digest)
        existing = head(client, bucket, key)
        if existing:
            if (existing['ContentLength'] != item['size']
                    or existing.get('Metadata', {}).get('sha256') != digest):
                raise ValueError('Existing object conflicts with checksum identity; refusing overwrite')
            verify_object(client, bucket, key, digest, item['size'])
            reused += 1
        else:
            # Managed transfer supports multipart objects larger than 5 GB.
            client.upload_file(str(path), bucket, key, ExtraArgs={
                'ACL': 'private', 'Metadata': {'sha256': digest},
                'ContentType': 'application/octet-stream'})
            verify_object(client, bucket, key, digest, item['size'])
            uploaded += 1
        print(f'Checked {len(seen)} unique objects', file=sys.stderr)
    # The manifest is the completion record: write it only after all objects pass.
    key = manifest_key(prefix, manifest['snapshot'], manifest_digest)
    existing = head(client, bucket, key)
    if existing:
        verify_object(client, bucket, key, manifest_digest, len(raw))
    else:
        client.put_object(Bucket=bucket, Key=key, Body=raw, ACL='private',
                          ContentType='application/json', Metadata={'sha256': manifest_digest})
        verify_object(client, bucket, key, manifest_digest, len(raw))
    return {'snapshot': manifest['snapshot'], 'manifest_key': key,
            'manifest_sha256': manifest_digest, 'uploaded_objects': uploaded,
            'reused_objects': reused, 'files': len(manifest['files'])}


def fetch_manifest(client, bucket, prefix, snapshot, digest, version=None):
    if not re.fullmatch(r'[a-f0-9]{64}', digest):
        raise ValueError('A pinned manifest SHA256 is required')
    response = client.get_object(Bucket=bucket, Key=manifest_key(prefix, snapshot, digest),
                                 **({'VersionId': version} if version else {}))
    try:
        raw = response['Body'].read(MAX_MANIFEST + 1)
    finally:
        response['Body'].close()
    if len(raw) > MAX_MANIFEST or hashlib.sha256(raw).hexdigest() != digest:
        raise ValueError('Manifest failed size/SHA256 verification')
    manifest = validate(json.loads(raw))
    if manifest['snapshot'] != snapshot:
        raise ValueError('Unexpected snapshot identity')
    return manifest


def versions(client, bucket, prefix, snapshot=None):
    search = f'{prefix}/manifests/'
    if snapshot:
        search += identifier(snapshot) + '/'
    rows = []
    pattern = re.compile(re.escape(f'{prefix}/manifests/') +
                         r'([A-Za-z0-9][A-Za-z0-9._-]{0,159})/([a-f0-9]{64})\.json')
    for page in client.get_paginator('list_object_versions').paginate(Bucket=bucket, Prefix=search):
        for group in ('Versions', 'DeleteMarkers'):
            for entry in page.get(group, []):
                match = pattern.fullmatch(entry['Key'])
                if not match:
                    continue
                name, digest = match.groups()
                version = entry['VersionId']
                row = {'snapshot': name, 'manifest_sha256': digest, 'manifest_version': version,
                       'latest': entry['IsLatest'], 'modified': entry['LastModified'].isoformat(),
                       'status': 'delete-marker' if group == 'DeleteMarkers' else 'manifest-verified'}
                if group == 'Versions':
                    if entry['Size'] > MAX_MANIFEST:
                        raise ValueError('Manifest exceeds size limit')
                    manifest = fetch_manifest(client, bucket, prefix, name, digest, version)
                    row.update(files=len(manifest['files']),
                               unique_bytes=sum({f['sha256']: f['size'] for f in manifest['files']}.values()),
                               access=manifest['access'],
                               pinned_files=sum(bool(f.get('object_version')) and
                                                f['object_version'] != 'null' for f in manifest['files']))
                rows.append(row)
    return sorted(rows, key=lambda row: (row['modified'], row['snapshot'], row['manifest_version']), reverse=True)


def print_versions(rows):
    if not rows:
        print('No completed backup manifests found. An upload in progress has no manifest yet.')
        return
    print('SNAPSHOT\tMODIFIED\tFILES\tUNIQUE BYTES\tSTATUS\tLATEST\tMANIFEST VERSION\tMANIFEST SHA256')
    for row in rows:
        print('\t'.join(str(value) for value in (
            row['snapshot'], row['modified'], row.get('files', '-'), row.get('unique_bytes', '-'),
            row['status'], row['latest'], row['manifest_version'], row['manifest_sha256'])))
    print('Manifest checksums verified; package payloads were not downloaded or reverified.', file=sys.stderr)


def fetch(client, bucket, prefix, manifest, output):
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    for item in manifest['files']:
        path = local_path(output, item['path'])
        if path.exists():
            if digest_file(path) != (item['sha256'], item['size']):
                raise ValueError('Existing local file differs; refusing overwrite')
            continue
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        response = client.get_object(Bucket=bucket, Key=payload_key(prefix, item),
                                     **({'VersionId': item['object_version']} if item.get('object_version') else {}))
        temporary = None
        try:
            with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.lake-', delete=False) as target:
                temporary = Path(target.name)
                digest, size = hashlib.sha256(), 0
                for chunk in iter(lambda: response['Body'].read(CHUNK), b''):
                    size += len(chunk)
                    if size > item['size']:
                        raise ValueError('Object exceeds its declared size')
                    digest.update(chunk)
                    target.write(chunk)
            if size != item['size'] or digest.hexdigest() != item['sha256']:
                raise ValueError('Downloaded object failed SHA256/size verification')
            # Atomic create without replacing a file created by another process.
            os.link(temporary, path)
        finally:
            response['Body'].close()
            if temporary:
                temporary.unlink(missing_ok=True)
    return {'snapshot': manifest['snapshot'], 'files_verified': len(manifest['files'])}


def select_repository(manifest, name):
    selected = [repo for repo in manifest.get('repositories', []) if repo['name'] == name]
    if len(selected) != 1:
        raise ValueError('Expected one repository in the recovery catalog')
    hashes = {item['sha256'] for item in selected[0]['files']}
    return validate({**manifest, 'repositories': selected,
                     'files': [item for item in manifest['files'] if item['sha256'] in hashes]})


def client_for(endpoint, region, profile=None):
    parsed = urlsplit(endpoint)
    if (parsed.scheme != 'https' or not parsed.hostname or parsed.username
            or parsed.password or parsed.path not in ('', '/') or parsed.query or parsed.fragment):
        raise ValueError('Endpoint must be an HTTPS origin')
    import boto3
    from botocore.config import Config
    return boto3.Session(profile_name=profile).client('s3', endpoint_url=endpoint, region_name=region,
                        config=Config(signature_version='s3v4',
                                      s3={'addressing_style': 'path'},
                                      retries={'mode': 'standard', 'max_attempts': 5},
                                      request_checksum_calculation='when_required',
                                      response_checksum_validation='when_required'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    planning = commands.add_parser('plan', help='Hash a selected directory; output a local manifest')
    planning.add_argument('--root', type=Path, required=True)
    planning.add_argument('--snapshot', required=True)
    planning.add_argument('--release', required=True)
    planning.add_argument('--access', choices=['public', 'private', 'mixed'], required=True)
    for name in ('push', 'fetch', 'versions', 'show'):
        sub = commands.add_parser(name)
        sub.add_argument('--bucket', required=True)
        sub.add_argument('--endpoint', required=True)
        sub.add_argument('--region', required=True)
        sub.add_argument('--prefix', default='pulp-package-lake')
        sub.add_argument('--profile', help='Local AWS credential profile')
        if name in ('push', 'fetch'):
            sub.add_argument('--apply', action='store_true')
        if name == 'versions':
            sub.add_argument('--snapshot', help='Limit listing to this exact snapshot')
            sub.add_argument('--json', action='store_true', help='Output machine-readable version records')
            continue
        if name == 'push':
            sub.add_argument('--root', type=Path, required=True)
            sub.add_argument('--manifest', type=Path, required=True)
        else:
            sub.add_argument('--snapshot', required=True)
            sub.add_argument('--manifest-sha256', required=True)
            sub.add_argument('--manifest-version', required=name == 'show',
                             help='Pinned S3 version from an SSH-sync receipt or versions listing')
            if name == 'fetch':
                sub.add_argument('--output', type=Path, required=True)
                sub.add_argument('--repository', help='Fetch only this published distribution')
    args = parser.parse_args()
    os.umask(0o077)
    try:
        if args.command == 'plan':
            sys.stdout.buffer.write(encode(plan(args.root, args.snapshot, args.release, args.access)))
            return 0
        relative_path(args.prefix)
        if args.command == 'push':
            manifest = validate(json.loads(args.manifest.read_bytes()))
            if not args.apply:
                print(json.dumps({'dry_run': True, 'snapshot': manifest['snapshot'],
                                  'files': len(manifest['files']),
                                  'unique_bytes': sum({f['sha256']: f['size'] for f in manifest['files']}.values())}))
                return 0
        client = client_for(args.endpoint, args.region, args.profile)
        if args.command == 'versions':
            result = versions(client, args.bucket, args.prefix, args.snapshot)
            if args.json:
                print(json.dumps(result, indent=2))
            else:
                print_versions(result)
            return 0
        if args.command == 'push':
            result = push(client, args.bucket, args.prefix, manifest, args.root)
        else:
            manifest = fetch_manifest(client, args.bucket, args.prefix, args.snapshot,
                                      args.manifest_sha256, args.manifest_version)
            if args.command == 'show':
                print(json.dumps(manifest, indent=2))
                return 0
            if args.repository:
                manifest = select_repository(manifest, args.repository)
            result = (fetch(client, args.bucket, args.prefix, manifest, args.output) if args.apply else
                      {'dry_run': True, 'snapshot': args.snapshot, 'files': len(manifest['files']),
                       'download_bytes': sum(f['size'] for f in manifest['files'])})
        print(json.dumps(result, indent=2))
    except Exception as exc:
        # SDK errors can contain signed URLs, request details or account data.
        message = str(exc) if isinstance(exc, ValueError) else type(exc).__name__
        print('Package lake operation failed: ' + message, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
