#!/usr/bin/env python3
"""Archive signed CI repository files once, with named objects and readable catalogs."""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import html
import io
import json
import os
from pathlib import Path
import re
import secrets
import sys
import tempfile
from urllib.parse import urlsplit

import package_lake as lake

SCHEMA = 'packetfence-readable-archive-v1'
PACKAGES = ('.deb', '.udeb', '.rpm', '.dsc', '.changes', '.buildinfo',
            '.tar.gz', '.tar.xz', '.tar.bz2', '.tar.zst', '.diff.gz')


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def kind(path):
    name = Path(path).name
    if any(part.startswith('.') or part.lower() in ('secrets', 'logs', 'conf', 'db')
           for part in Path(path).parts):
        return None
    if name.endswith(PACKAGES):
        return 'package'
    if ('dists' in Path(path).parts or 'repodata' in Path(path).parts
            or name in ('GPG_PUBLIC_KEY', 'pipeline-lock.json', 'dependency-selection.json')
            or name.startswith(('APT-GPG-KEY', 'RPM-GPG-KEY'))
            or name.endswith(('.asc', '.sig'))):
        return 'metadata'
    return None


def plan(tree, environment, pipeline, release, phase):
    if environment not in ('staging', 'production') or phase not in ('dependencies', 'packages'):
        raise ValueError('Select staging/production and dependencies/packages explicitly')
    if not re.fullmatch('[1-9][0-9]*', pipeline) or not re.fullmatch(r'[0-9]+\.[0-9]+', release):
        raise ValueError('Invalid pipeline ID or release')
    inventory = lake.plan(tree, 'ci-' + pipeline, release, 'public')
    files, excluded = [], []
    for item in inventory['files']:
        category = kind(item['path'])
        if category:
            files.append({**item, 'kind': category})
        elif Path(item['path']).name in ('index.html', 'PULP_MANIFEST'):
            excluded.append(item['path'])
        else:
            raise ValueError('Unexpected file in generated repository: ' + item['path'])
    if not any(item['kind'] == 'package' for item in files):
        raise ValueError('No packages in archive input')
    return {'schema': SCHEMA, 'environment': environment, 'pipeline': pipeline,
            'release': release, 'phase': phase, 'files': files, 'excluded_paths': excluded}


def private_versioned_bucket(client, bucket):
    acl = client.get_bucket_acl(Bucket=bucket)
    if any(grant['Grantee'].get('Type') != 'CanonicalUser'
           or grant['Grantee'].get('ID') != acl['Owner']['ID'] for grant in acl['Grants']):
        raise ValueError('Archive bucket ACL must be owner-only')
    try:
        policy = json.loads(client.get_bucket_policy(Bucket=bucket)['Policy'])
    except Exception as error:
        if getattr(error, 'response', {}).get('Error', {}).get('Code') != 'NoSuchBucketPolicy':
            raise
        policy = {}
    statements = policy.get('Statement', [])
    for statement in [statements] if isinstance(statements, dict) else statements:
        if statement.get('Effect') == 'Allow' and (
                not statement.get('Principal') or '*' in json.dumps(statement['Principal'])
                or 'NotPrincipal' in statement):
            raise ValueError('Archive bucket policy permits broad access')
    if client.get_bucket_versioning(Bucket=bucket).get('Status') != 'Enabled':
        raise ValueError('Archive bucket versioning must be enabled')


def verify(client, bucket, key, item, version=None):
    stored = client.head_object(Bucket=bucket, Key=key,
                                **({'VersionId': version} if version else {}))
    actual_version = stored.get('VersionId')
    if not actual_version or actual_version == 'null' or (version and actual_version != version):
        raise ValueError('Archive object must have the expected non-null version')
    if (stored['ContentLength'] != item['size']
            or stored.get('Metadata', {}).get('sha256') != item['sha256']):
        raise ValueError('WARNING: existing object hash/size mismatch; refusing replacement')
    lake.verify_object(client, bucket, key, item['sha256'], item['size'], actual_version)
    return actual_version


def list_keys(client, bucket, prefix):
    for page in client.get_paginator('list_objects_v2').paginate(Bucket=bucket, Prefix=prefix):
        for item in page.get('Contents', []):
            yield item['Key']


def new_json(client, bucket, key, value):
    raw = encoded(value)
    if lake.head(client, bucket, key) is not None:
        raise ValueError('Generated archive key already exists; refusing overwrite')
    item = {'sha256': hashlib.sha256(raw).hexdigest(), 'size': len(raw)}
    client.put_object(Bucket=bucket, Key=key, Body=raw, ContentType='application/json',
                      Metadata={'sha256': item['sha256']})
    return {**item, 'object_key': key, 'object_version': verify(client, bucket, key, item)}


def existing_object(client, bucket, prefix, item):
    index_prefix = prefix + '/by-sha256/' + item['sha256'] + '/'
    for key in list_keys(client, bucket, index_prefix):
        response = client.get_object(Bucket=bucket, Key=key)
        try:
            raw = response['Body'].read(16385)
        finally:
            response['Body'].close()
        if len(raw) > 16384:
            raise ValueError('Invalid archive object index size')
        record = json.loads(raw)
        object_key = lake.relative_path(record['object_key'])
        if (not object_key.startswith(prefix + '/packages/')
                and not object_key.startswith(prefix + '/metadata/')):
            raise ValueError('Archive index points outside the named object pool')
        if record['sha256'] != item['sha256'] or record['size'] != item['size']:
            raise ValueError('Archive object index conflicts with requested checksum')
        verify(client, bucket, object_key, item, record['object_version'])
        return {key: record[key] for key in ('object_key', 'object_version')}
    return None


def archive_object(client, bucket, prefix, root, item):
    source = lake.local_path(root, item['path'])
    if lake.digest_file(source) != (item['sha256'], item['size']):
        raise ValueError('Source changed since archive planning')
    def transfer(key):
        client.upload_file(str(source), bucket, key, ExtraArgs={
            'ContentType': 'application/octet-stream', 'Metadata': {'sha256': item['sha256']}})
    return named_object(client, bucket, prefix, item, source.name, transfer)


def named_object(client, bucket, prefix, item, filename, transfer):
    if lake.relative_path(filename) != Path(filename).name:
        raise ValueError('Named object filename must be a basename')
    name_id = hashlib.sha256(filename.encode()).hexdigest()
    name_prefix = prefix + '/by-name/' + name_id + '/'
    if item['kind'] == 'package':
        prior = {key[len(name_prefix):].split('/')[0]
                 for key in list_keys(client, bucket, name_prefix)}
        if prior - {item['sha256']}:
            print('WARNING: different bytes already archived for ' + filename
                  + '; preserving both checksum identities', file=sys.stderr)
    record = existing_object(client, bucket, prefix, item)
    created = record is None
    if created:
        token = secrets.token_hex(16)
        category = 'packages' if item['kind'] == 'package' else 'metadata'
        key = '/'.join((prefix, category, filename, item['sha256'], token, filename))
        if len(key.encode()) > 1024 or lake.head(client, bucket, key) is not None:
            raise ValueError('Generated package object key is invalid or occupied')
        # Fresh unpredictable names support endpoints without conditional multipart completion.
        transfer(key)
        record = {'object_key': key, 'object_version': verify(client, bucket, key, item)}
        new_json(client, bucket, prefix + '/by-sha256/' + item['sha256'] + '/' + token + '.json',
                 {**record, 'sha256': item['sha256'], 'size': item['size']})
    if item['kind'] == 'package' and item['sha256'] not in prior:
        new_json(client, bucket, name_prefix + item['sha256'] + '/' + secrets.token_hex(16) + '.json',
                 {**record, 'filename': filename, 'sha256': item['sha256'], 'size': item['size']})
    return {**item, **record}, created


def catalog_html(catalog):
    rows = []
    for item in catalog['files']:
        cells = [item['path'], item['kind'], str(item['size']), item['sha256'], item['object_key']]
        rows.append('<tr>' + ''.join('<td>' + html.escape(value) + '</td>' for value in cells) + '</tr>')
    return ('<!doctype html><html lang="en"><meta charset="utf-8"><title>PacketFence package archive</title>'
            '<h1>PacketFence ' + html.escape(catalog['release']) + ' — pipeline '
            + html.escape(catalog['pipeline']) + '</h1><p>' + html.escape(catalog['environment'])
            + ' / ' + html.escape(catalog['phase']) + '</p>'
            '<p>Private archive. Package paths reference shared objects; download through authenticated S3 access. '
            'catalog.json records exact object versions for recovery.</p><table><thead><tr>'
            '<th>Repository path</th><th>Type</th><th>Bytes</th><th>SHA256</th><th>Object key</th>'
            '</tr></thead><tbody>' + ''.join(rows) + '</tbody></table></html>').encode()


def push(client, bucket, prefix, root, catalog):
    lake.relative_path(prefix)
    private_versioned_bucket(client, bucket)
    # Detect a changed local source before transferring any payload.
    for item in catalog['files']:
        if lake.digest_file(lake.local_path(root, item['path'])) != (item['sha256'], item['size']):
            raise ValueError('Source changed since archive planning')
    files, created = [], 0
    for item in catalog['files']:
        record, added = archive_object(client, bucket, prefix, root, item)
        files.append(record)
        created += int(added)
    catalog = {**catalog, 'bucket': bucket, 'files': files}
    token = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + secrets.token_hex(16)
    folder = '/'.join((prefix, 'catalogs', catalog['environment'], catalog['release'],
                       catalog['pipeline'], catalog['phase'], token))
    stream = io.StringIO()
    fields = ('path', 'kind', 'size', 'sha256', 'object_key', 'object_version')
    writer = csv.DictWriter(stream, fieldnames=fields, extrasaction='ignore')
    writer.writeheader()
    for item in files:
        # Prevent formula execution when an operator opens the catalog in a spreadsheet.
        writer.writerow({k: "'" + v if isinstance(v, str) and v.startswith(('=', '+', '-', '@')) else v
                         for k, v in item.items()})
    for name, raw, mime in [('index.html', catalog_html(catalog), 'text/html'),
                            ('catalog.csv', stream.getvalue().encode(), 'text/csv')]:
        key = folder + '/' + name
        if lake.head(client, bucket, key) is not None:
            raise ValueError('Generated catalog key already exists')
        digest = hashlib.sha256(raw).hexdigest()
        client.put_object(Bucket=bucket, Key=key, Body=raw, ContentType=mime, Metadata={'sha256': digest})
        verify(client, bucket, key, {'sha256': digest, 'size': len(raw)})
    receipt = new_json(client, bucket, folder + '/catalog.json', catalog)
    return {'bucket': bucket, 'catalog': receipt, 'uploaded_objects': created,
            'reused_objects': len(files) - created, 'files': len(files), 'catalog_prefix': folder}


def read_catalog(path, digest, bucket, prefix):
    raw = path.read_bytes()
    if len(raw) > lake.MAX_MANIFEST or hashlib.sha256(raw).hexdigest() != digest:
        raise ValueError('Catalog failed pinned SHA256 verification')
    catalog = json.loads(raw)
    if catalog.get('schema') != SCHEMA or catalog.get('bucket') != bucket:
        raise ValueError('Catalog schema/bucket mismatch')
    lake.validate({'schema': lake.SCHEMA, 'snapshot': 'restore', 'release': catalog['release'],
                   'access': 'public', 'files': catalog['files']})
    for item in catalog['files']:
        key = lake.relative_path(item['object_key'])
        if not any(key.startswith(prefix + '/' + part + '/') for part in ('packages', 'metadata')):
            raise ValueError('Catalog points outside the named object pool')
        if not isinstance(item['object_version'], str) or item['object_version'] in ('', 'null'):
            raise ValueError('Catalog lacks a pinned object version')
    return catalog


def restore(client, bucket, catalog, output):
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    for item in catalog['files']:
        path = lake.local_path(output, item['path'])
        if path.exists():
            if lake.digest_file(path) != (item['sha256'], item['size']):
                raise ValueError('Existing local file differs; refusing overwrite')
            continue
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        response = client.get_object(Bucket=bucket, Key=item['object_key'], VersionId=item['object_version'])
        try:
            with tempfile.NamedTemporaryFile(dir=path.parent) as temporary:
                digest, size = hashlib.sha256(), 0
                for chunk in iter(lambda: response['Body'].read(lake.CHUNK), b''):
                    size += len(chunk)
                    if size > item['size']:
                        raise ValueError('Downloaded file exceeds catalog size')
                    digest.update(chunk)
                    temporary.write(chunk)
                if (digest.hexdigest(), size) != (item['sha256'], item['size']):
                    raise ValueError('Downloaded file failed checksum verification')
                temporary.flush()
                os.link(temporary.name, path)
        finally:
            response['Body'].close()
    return {'files_verified': len(catalog['files'])}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tree', type=Path)
    parser.add_argument('--environment', choices=['staging', 'production'])
    parser.add_argument('--pipeline')
    parser.add_argument('--release')
    parser.add_argument('--phase', choices=['dependencies', 'packages'])
    parser.add_argument('--restore-catalog', type=Path)
    parser.add_argument('--catalog-sha256')
    parser.add_argument('--bucket', required=True)
    parser.add_argument('--endpoint', required=True)
    parser.add_argument('--region', required=True)
    parser.add_argument('--prefix', default='pulp-package-lake')
    parser.add_argument('--profile')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    url = urlsplit(args.endpoint)
    if (url.scheme != 'https' or not url.hostname or url.username or url.password
            or url.path not in ('', '/') or url.query or url.fragment):
        parser.error('Object Storage endpoint must be an HTTPS origin')
    lake.relative_path(args.prefix)
    if args.restore_catalog:
        if any((args.tree, args.environment, args.pipeline, args.release, args.phase)) or not args.catalog_sha256:
            parser.error('Restore requires --catalog-sha256 and no upload arguments')
        catalog = read_catalog(args.restore_catalog, args.catalog_sha256, args.bucket, args.prefix)
    else:
        if not all((args.tree, args.environment, args.pipeline, args.release, args.phase)) or args.catalog_sha256:
            parser.error('Upload requires --tree, --environment, --pipeline, --release and --phase')
        catalog = plan(args.tree, args.environment, args.pipeline, args.release, args.phase)
    if args.apply:
        client = lake.client_for(args.endpoint, args.region, args.profile)
        result = (restore(client, args.bucket, catalog, args.output) if args.restore_catalog
                  else push(client, args.bucket, args.prefix, args.tree, catalog))
    else:
        result = catalog
    if not args.restore_catalog:
        args.output.write_bytes(encoded(result))
    print(json.dumps({'files': len(catalog['files']), 'applied': args.apply, 'output': str(args.output)}))


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('Package archive failed; no completion receipt was written. Check configuration, access and object integrity. No credentials were logged.', file=sys.stderr)
        raise SystemExit(1)
