#!/usr/bin/env python3
"""Regenerate conf/redis_*.conf.example from Debian's shipped redis.conf.

The three PacketFence files are Debian's redis.conf with a small set of
PacketFence deltas applied. Re-applying that set mechanically is what keeps the
next redis bump from turning into a hand-merge -- the last one glued
`auto-aof-rewrite-percentage 100` onto a comment line.

Every delta asserts that its anchor matches exactly once, so an upstream
rewording fails the run rather than silently dropping a PacketFence setting.

Usage, from the repo root:

    # grab the baseline from the redis-server package for the target release
    docker run --rm -v "$PWD/tmp":/out debian:13 bash -c \
      'apt-get update -qq && cd /tmp && apt-get download redis-server && \
       dpkg-deb -x redis-server*.deb x && cp x/etc/redis/redis.conf /out/'

    python3 addons/dev-helpers/port-redis-conf.py tmp/redis.conf conf/

Then confirm only the intended settings moved:

    git diff -U0 conf/redis_cache.conf.example | grep -E '^[-+][a-z]'
"""
import sys

BASE = sys.argv[1]
OUTDIR = sys.argv[2]

# Per-file values. Everything else is identical across the three files.
FILES = {
    'redis_cache': dict(
        bind='bind 127.0.0.1 100.64.0.1',
        port='port 6379',
        unixsocket='unixsocket /usr/local/pf/var/run/redis_cache.sock',
        pidfile='pidfile /usr/local/pf/var/run/redis_cache.pid',
        logfile='#logfile /var/log/redis/redis-server.log',
        syslog_ident='syslog-ident redis-cache',
        dir='dir /usr/local/pf/var/redis_cache',
        hz='hz 10',
    ),
    'redis_ntlm_cache': dict(
        bind='bind 127.0.0.1',
        port='port 6383',
        unixsocket='unixsocket /usr/local/pf/var/run/redis_ntlm_cache.sock',
        pidfile='pidfile /usr/local/pf/var/run/redis_ntlm_cache.pid',
        logfile='# logfile /usr/local/pf/logs/redis_ntlm_cache.log',
        syslog_ident='syslog-ident redis-ntlm-cache',
        dir='dir /usr/local/pf/var/redis_ntlm_cache',
        hz='hz 10',
    ),
    'redis_queue': dict(
        bind='bind 127.0.0.1 100.64.0.1',
        port='port 6380',
        unixsocket='unixsocket %%install_dir%%/var/run/%%name%%.sock',
        pidfile='pidfile %%install_dir%%/var/run/%%name%%.pid',
        logfile='#logfile %%install_dir%%/logs/%%name%%.log',
        syslog_ident='syslog-ident redis-queue',
        dir='dir %%install_dir%%/var/%%name%%',
        hz='hz 50',
    ),
}

base_lines = open(BASE).read().split('\n')


def build(name, v):
    lines = list(base_lines)

    def sub(old, new):
        """Replace the single line `old` with `new` (may be several lines)."""
        hits = [i for i, l in enumerate(lines) if l == old]
        assert len(hits) == 1, f'{name}: {len(hits)} matches for {old!r}'
        i = hits[0]
        lines[i:i + 1] = new if isinstance(new, list) else [new]

    def after(anchor, extra):
        hits = [i for i, l in enumerate(lines) if l == anchor]
        assert len(hits) == 1, f'{name}: {len(hits)} matches for anchor {anchor!r}'
        i = hits[0]
        lines[i + 1:i + 1] = extra

    # NETWORK
    sub('bind 127.0.0.1 -::1', v['bind'])
    # PF binds to loopback and the connector range only; the portal and services
    # reach it over the unix socket, so the protected-mode guard is redundant.
    sub('protected-mode yes', 'protected-mode no')
    sub('port 6379', v['port'])
    sub('# unixsocket /run/redis/redis-server.sock',
        v['unixsocket'])
    sub('# unixsocketperm 700', 'unixsocketperm 660')
    sub('tcp-keepalive 300', 'tcp-keepalive 0')

    # GENERAL — systemd units run redis in the foreground.
    sub('daemonize yes', 'daemonize no')
    sub('pidfile /run/redis/redis-server.pid', v['pidfile'])
    sub('logfile /var/log/redis/redis-server.log', v['logfile'])
    sub('# syslog-enabled no', 'syslog-enabled yes')
    sub('# syslog-ident redis', v['syslog_ident'])
    sub('# syslog-facility local0', 'syslog-facility local5')
    sub('databases 16', 'databases 1')

    # SNAPSHOTTING
    after('# save 3600 1 300 100 60 10000',
          ['save 900 1', 'save 300 10', 'save 60 10000'])
    sub('dir /var/lib/redis', v['dir'])

    # REPLICATION
    sub('repl-diskless-sync yes', 'repl-diskless-sync no')

    # SECURITY — rename-command is deprecated in Redis 8 in favour of ACLs but
    # still honoured; kept as-is so this stays a port, not a redesign.
    after('# AOF file or transmitted to replicas may cause problems.',
          ['rename-command CONFIG ""', 'rename-command DEBUG ""'])

    # LUA
    sub('# lua-time-limit 5000', 'lua-time-limit 5000')

    # ADVANCED
    sub('hz 10', v['hz'])

    return '# Copyright (C) Inverse inc.\n' + '\n'.join(lines)


for name, v in FILES.items():
    out = f'{OUTDIR}/{name}.conf.example'
    open(out, 'w').write(build(name, v))
    print(f'wrote {out}')
