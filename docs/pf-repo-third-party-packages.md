# Third-party packages in the PacketFence apt repo

Source: `http://inverse.ca/downloads/PacketFence/debian/16.0/dists/bookworm` (amd64).
Trixie column: candidate version in Debian 13 `main` (trixie, trixie-updates, trixie-security), from `apt-cache policy`.
`(none)` means not in trixie `main`; snmp-mibs-downloader is in trixie non-free.

Packages marked "Rebuild" are built from recipes in `addons/third-party/` (see its README).
Recipes so far: freeradius, libapache2-mod-systemd, libcisco-accesslist-parser-perl,
libnet-nessus-xmlrpc-perl, libparse-eyapp-perl, sscep.

| Package | PF repo (bookworm) | Debian trixie | Recommendation | Notes |
|---|---|---|---|---|
| containerd.io | 1.6.31-1 | 2.4.2-3~debian.13~trixie | Use upstream | Docker publishes trixie builds in its own repo |
| docker-ce | 5:26.1.3-1~debian.12~bookworm | 5:29.9.2-1~debian.13~trixie | Use upstream | Docker publishes trixie builds in its own repo |
| docker-ce-cli | 5:26.1.3-1~debian.12~bookworm | 5:29.9.2-1~debian.13~trixie | Use upstream | Docker publishes trixie builds in its own repo |
| docker-ce-rootless-extras | 5:26.1.3-1~debian.12~bookworm | 5:29.9.2-1~debian.13~trixie | Use upstream | Docker publishes trixie builds in its own repo |
| docker-scan-plugin | 0.23.0~debian-bookworm | (none) | Drop | Discontinued by Docker; no trixie build |
| freeradius | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-common | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-config | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-dbg | 4:3.2.11+git | (none) | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-dhcp | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-freetds | 4:3.2.11+git | (none) | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-kafka | 4:3.2.11+git | (none) | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-krb5 | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-ldap | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-memcached | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-mysql | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-perl-util | 4:3.2.11+git | (none) | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-postgresql | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-python3 | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-redis | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-rest | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-unbound | 4:3.2.11+git | (none) | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-unixodbc | 4:3.2.11+git | (none) | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-utils | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-utils-json | 4:3.2.11+git | (none) | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| freeradius-yubikey | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| galera-4 | 26.4.16-deb12 | 26.4.23-0+deb13u1 | Use Debian | Trixie has the same or a newer version |
| galera-arbitrator-4 | 26.4.16-deb12 | 26.4.23-0+deb13u1 | Use Debian | Trixie has the same or a newer version |
| haproxy | 2.2.15-1 | 3.0.11-1+deb13u4 | Decide later | PF 2.2 vs trixie 3.0; haproxy-* containers install it unpinned |
| haproxy-dbgsym | 2.2.15-1 | (none) | Debug symbols | Follows its parent package |
| haproxy-doc | 2.2.15-1 | 3.0.11-1+deb13u4 | Decide later | PF 2.2 vs trixie 3.0; haproxy-* containers install it unpinned |
| keepalived | 1:2.3.4-1 | 1:2.3.3-1 | Probably use Debian | Patch-level difference only |
| keepalived-dbgsym | 1:2.3.4-1 | (none) | Debug symbols | Follows its parent package |
| libapache2-mod-apreq2 | 2.17-3~bpo12+1 | 2.17-7+b2 | Use Debian | Trixie has the same or a newer version |
| libapache2-mod-systemd | 0.1-1 | (none) | Recipe `libapache2-mod-systemd` | Built from httpd 2.4.69's mod_systemd.c; trixie's apache2-bin doesn't include it |
| libapache2-mod-systemd-dbgsym | 0.1-1 | (none) | Debug symbols | Follows its parent package |
| libapache2-request-perl | 2.17-3~bpo12+1 | 2.17-7+b2 | Use Debian | Trixie has the same or a newer version |
| libapreq2-3 | 2.17-3~bpo12+1 | (none) | Use Debian | Renamed libapreq2-3t64 in trixie |
| libauthen-radius-perl | 0.33-1 | 0.33-1 | Use Debian | Trixie has the same or a newer version |
| libcisco-accesslist-parser-perl | 0.0.2-1 | (none) | Recipe `libcisco-accesslist-parser-perl` | inverse-inc/Cisco-AccessList-Parser fork; built with eyapp |
| libcrypt-openssl-pkcs12-perl | 1.9-3 | 1.94-1+b1 | Use Debian | Trixie has the same or a newer version |
| libcrypt-openssl-pkcs12-perl-dbgsym | 1.9-3 | (none) | Debug symbols | Follows its parent package |
| libcrypt-smime-perl | 1:0.28-2 | 0.31-1 | Use Debian | Trixie has the same or a newer version |
| libdata-powerset-perl | 0.05-1 | (none) | Drop | Not used by PacketFence |
| libdbd-mysql-perl | 4.052-1.1 | 4.053-1 | Use Debian | Trixie has the same or a newer version |
| libdbd-mysql-perl-dbgsym | 4.052-1.1 | (none) | Debug symbols | Follows its parent package |
| libfreeradius3 | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| libfreeradius-dev | 4:3.2.11+git | 3.2.7+dfsg-1+deb13u2 | Recipe `freeradius` | inverse-inc/freeradius-server fork, its own debian/; radiusd container pins 4:3.2.11+git |
| libjq-xs-perl | 2.02-1+deb12u1 | (none) | Drop | Not used by PacketFence |
| libnet-nessus-rest-perl | 0.7-1 | 0.7.0-3 | Use Debian | Trixie has the same or a newer version |
| libnet-nessus-xmlrpc-perl | 0.40-1 | 0.30-3 | Recipe `libnet-nessus-xmlrpc-perl` | PF 0.40 is CPAN 0.30 + PF patches (report_filenbe_download); rebuilt as 0.30+pf1, above Debian 0.30-3 |
| libparse-eyapp-perl | 1.21-1 | (none) | Recipe `libparse-eyapp-perl` | CPAN 1.21; build and runtime dependency of the Cisco parser |
| libposix-atfork-perl | 0.02-2 | 0.04-2+b5 | Use Debian | Trixie has the same or a newer version |
| libposix-atfork-perl-dbgsym | 0.02-2 | (none) | Debug symbols | Follows its parent package |
| libsereal-decoder-perl | 5.004+ds-1 | 5.004+ds-1+b3 | Use Debian | Trixie has the same or a newer version |
| libsereal-encoder-perl | 5.004+ds-1 | 5.004+ds-1+b3 | Use Debian | Trixie has the same or a newer version |
| libsereal-perl | 5.004-1 | 5.004-1 | Use Debian | Trixie has the same or a newer version |
| netdata | 1:1.10.0-1 | (none) | Probably drop | Removed from Debian after bookworm; PF runs netdata in Docker; not in debian/control |
| netdata-data | 1:1.10.0-1 | (none) | Probably drop | Removed from Debian after bookworm; PF runs netdata in Docker; not in debian/control |
| proxysql | 2.6.0 | (none) | Decide later | Not in Debian; required by packetfence or a container |
| python3-impacket | 0.10.0-4 | 0.12.0-3 | Use Debian | Trixie has the same or a newer version |
| python3-slip | 0.6.5-2 | (none) | Probably drop | Dropped from Debian after bullseye; nothing in debian/control uses it |
| python3-slip-dbus | 0.6.5-2 | (none) | Probably drop | Dropped from Debian after bullseye; nothing in debian/control uses it |
| snmp-mibs-downloader | 1.5 | (none) | Decide later | Debian 1.7 is in non-free; packetfence depends on it |
| sscep | 0.9.0-1 | (none) | Rebuild | Not in Debian; required by packetfence or a container |
| sscep-dbgsym | 0.9.0-1 | (none) | Debug symbols | Follows its parent package |
| vim-haproxy | 2.2.15-1 | 3.0.11-1+deb13u4 | Decide later | PF 2.2 vs trixie 3.0; haproxy-* containers install it unpinned |

## Decide later

- **proxysql**: PF ships 2.6.0, and ProxySQL publishes no trixie build of any
  2.x release. Either switch to 3.0.x from ProxySQL's own repo
  (`repo.proxysql.com/ProxySQL/proxysql-3.0.x/trixie`, 3.0.3 to 3.0.11; needs
  `proxysql.conf` and the read-only handler re-tested), or build 2.x from source.
- **haproxy**: PF ships 2.2.15 (end of life), trixie has 3.0.11 (LTS).
  `debian/control` only needs >= 2.2; using Debian's needs the generated
  haproxy configs checked on 3.0.
- **snmp-mibs-downloader**: packetfence depends on it. Debian 1.7 is in trixie
  non-free; either enable non-free on installs or rebuild it into the PF repo.
