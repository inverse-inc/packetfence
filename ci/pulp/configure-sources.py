#!/usr/bin/env python3
"""Disable old PacketFence inputs in a disposable build/validation environment."""
import configparser
import sys
from pathlib import Path

def configure(kind, root=Path('/')):
    if kind == 'deb':
        paths = [(root / 'etc/apt/sources.list'), *(root / 'etc/apt/sources.list.d').glob('*.list')]
        for path in paths:
            if path.exists():
                path.write_text(''.join('# Pulp CI: ' + line if '/downloads/PacketFence/' in line
                                        and not line.lstrip().startswith('#') else line
                                        for line in path.read_text().splitlines(True)))
        for path in (root / 'etc/apt/sources.list.d').glob('*.sources'):
            blocks = path.read_text().split('\n\n')
            path.write_text('\n\n'.join(b for b in blocks if '/downloads/PacketFence/' not in b))
    else:
        for path in (root / 'etc/yum.repos.d').glob('*.repo'):
            config = configparser.ConfigParser(interpolation=None)
            config.read(path)
            for section in config.sections():
                if '/downloads/PacketFence/' in config.get(section, 'baseurl', fallback=''):
                    config.set(section, 'enabled', '0')
            with path.open('w') as output:
                config.write(output)


if __name__ == '__main__':
    configure(sys.argv[1])
