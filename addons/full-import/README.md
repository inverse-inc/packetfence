
This is a quick readme to describe the export/import process. We should formalize this in our official documentation.

== Assumptions and limitations

 * You can export on any PacketFence version above 10.3.0
 * You can import on any PacketFence version above 11.0.0
 * The import process needs to be done on a standalone server. Restoring directly to clusters is currently unsupported
  * NOTE: Once you restored to your standalone server, you can make it a cluster by joining other machines to it and creating your cluster.conf but this is relatively advanced and out of scope of this document
 * Restoring on a fresh install of PacketFence is recommended although
   restoring on an existing instance can work but your milleage may vary
 * The import process will not modify network cards configuration of your server: it will
   only update PacketFence IP configuration. You need to define targeted IP
   addresses on network cards before running import process.
 * This process will only restore the files that can be edited via the admin interface which include:
  * Standard configuration files in /usr/local/pf/conf/*.conf
  * Connection profiles html templates in /usr/local/pf/html/captive-portal/profile-templates/
  * Standard certificates
   * /usr/local/pf/conf/ssl/*
   * /usr/local/pf/raddb/certs/*
 * Here is a short list of the configuration files that will not be restored. Changes to these files need to be migrated manually. This list is not meant to be complete:
  * /usr/local/pf/conf/radiusd/*
  * /usr/local/pf/conf/log.conf
  * /usr/local/pf/conf/log.conf.d/*
  * /usr/local/pf/conf/iptables.conf

== Prepare the environment (when on devel only)

```
# Replace 11.0 with the current devel version
cp db/pf-schema-X.Y.sql db/pf-schema-11.0.sql
```

```
# Replace 10.3-11.0 with the current stable and current devel version
cp db/upgrade-X.X-X.Y.sql db/upgrade-10.3-11.0.sql
```

== Start the export process

NOTE: When you are in a cluster, you need to perform this process on the first member of the incoming addresses of your database cluster. To find the member, run `show status like 'wsrep_incoming_addresses';` inside your MariaDB instance and the first IP will be the one where you need to perform the export process 

If the nightly export done at 0h30 everyday is fine and you don't need the latest data, then you can skip this step. Otherwise to have the latest data and configuration in your export, run:

```
/usr/local/pf/addons/backup-and-maintenance.sh
```

Next, you need to obtain a copy of the full-import tool (can currently be found here: https://github.com/inverse-inc/packetfence/tree/feature/full-import/addons/full-import). This needs to be installed in /usr/local/pf/addons/full-import/

Next, run the export script:

```
/usr/local/pf/addons/full-import/export.sh /tmp/export.tgz
```

The command above will create your export archive in /tmp/export.tgz. You will now need to copy this file to your new servers using scp or your prefered mechanism

== Start the import process

You first need to have a PacketFence 11.0 installation done on a standalone server following the instructions in our install guide. You don't need to go through the configurator unless you want to modify IP settings of the server.

The import script will guide you through the restore of the database, the configuration files and will help adjust the IP configuration if necessary.

If your export archive used MariaDB backup instead of mysqldump (your DB
backup filename contains `xbstream`), then you need to install identical
MariaDB-backup on your new server:

If you are restoring from PacketFence 10.3:
```
# CentOS/RHEL
yum remove MariaDB-backup
yum localinstall https://www.packetfence.org/downloads/PacketFence/CentOS7/x86_64/RPMS/MariaDB-backup-10.2.37-1.el7.centos.x86_64.rpm


# Debian
wget -O /root/mariadb-backup-10.2_10.2.37.deb https://www.packetfence.org/downloads/PacketFence/debian-lastrelease/pool/stretch/m/mariadb-10.2/mariadb-backup-10.2_10.2.37+maria~stretch_amd64.deb
dpkg-deb -xv /root/mariadb-backup-10.2_10.2.37.deb /root/mariadb-backup
mv /root/mariadb-backup/usr/bin/mariabackup /usr/local/bin/mariabackup
mv /root/mariadb-backup/usr/bin/mbstream /usr/local/bin/mbstream
```

If you are restoring from PacketFence 11.0 or above:
```
# CentOS/RHEL
yum install MariaDB-backup --enablerepo=packetfence

# Debian
apt install mariadb-backup
```

Now, start the import process using the export archive you made on the other server:

```
/usr/local/pf/addons/full-import/import.sh /tmp/export.tgz
```

Once the process is completed, you should see the following:

```
Completed import of the database and the configuration! Complete any necessary adjustments and restart PacketFence
```

If that's not the case, check the output above to understand why the process failed.

If you restored from PacketFence 10.3 and you used MariaDB-backup for your
restore, update it back to the right version:

```
# CentOS/RHEL
yum update MariaDB-backup --enablerepo=packetfence

# Debian
rm /root/mariadb-backup/usr/bin/mariabackup
rm /root/mariadb-backup/usr/bin/mbstream
```
