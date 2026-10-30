#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path
kind = sys.argv[1]
target = {'deb': 'debian/bookworm', 'rpm': 'centos/8'}[kind]
lock = json.loads(Path('pipeline-lock.json').read_text())
for entry in lock['targets'][target]['overrides']:
    if entry['use'] not in ('build', 'both'):
        continue
    info = entry['identity']
    # -- ends option parsing; argv lists prevent package metadata becoming shell code.
    if kind == 'deb':
        package = info['package'] + '=' + info['version']
        command = ['apt-get', 'install', '-y', '--allow-downgrades', '--', package]
    else:
        package = info['package'] + '-' + info['version'] + '.' + info['architecture']
        import rpm
        installed = subprocess.run(['rpm', '-q', '--qf', '%{EPOCHNUM}:%{VERSION}-%{RELEASE}',
                                    info['package'] + '.' + info['architecture']],
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                   universal_newlines=True)
        def evr(value):
            epoch, tail = value.split(':', 1)
            version, release = tail.rsplit('-', 1)
            return epoch, version, release
        action = 'install'
        if installed.returncode == 0 and rpm.labelCompare(evr(installed.stdout), evr(info['version'])) > 0:
            action = 'downgrade'
        command = ['dnf', action, '-y', '--', package]
    subprocess.run(command, check=True)
