#!/usr/bin/env python3
"""Reject another release's lock, including after artifact restoration."""
import json
import os
import re
import sys
from pathlib import Path
lock = json.loads(Path(sys.argv[1]).read_text())
match = re.fullmatch(r'PacketFence (\d+\.\d+)\.\d+\s*', Path('conf/pf-release').read_text())
if not match or lock.get('schema') != 1 or lock.get('release') != match[1]:
    raise SystemExit('Dependency lock does not match conf/pf-release')
if lock.get('pipeline') != os.environ.get('CI_PIPELINE_ID') or lock.get('commit') != os.environ.get('CI_COMMIT_SHA'):
    raise SystemExit('Dependency lock belongs to another pipeline/commit')
