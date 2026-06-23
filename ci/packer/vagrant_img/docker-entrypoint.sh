#!/bin/bash
# Start apt-cacher-ng so QEMU VM apt installs are cached across builds.
# The VM reaches the proxy at 10.0.2.2:3142 (QEMU user-mode gateway).
# Mount /var/cache/apt-cacher-ng as a Docker volume to persist cache across CI jobs.
/usr/sbin/apt-cacher-ng ForeGround=0 2>/dev/null || true
exec "$@"
