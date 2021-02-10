#!/bin/sh
# see https://github.com/vagrant-libvirt/vagrant-libvirt/issues/851#issuecomment-745261213

# repeat what machine-ids does in sysprep as this script needs to run via customize
# which has a bug resulting in the machine-ids being regenerated

if [ -f /etc/machine-id ]
then
    truncate --size=0 /etc/machine-id
fi

if [ -f /var/lib/dbus/machine-id ]
then
    truncate --size=0 /run/machine-id
fi

# for debian based systems ensure host keys regenerated on boot
if [ -e /usr/sbin/dpkg-reconfigure ]
then
    printf "@reboot root command bash -c 'export PATH=$PATH:/usr/sbin ; export DEBIAN_FRONTEND=noninteractive ; export DEBCONF_NONINTERACTIVE_SEEN=true ; /usr/sbin/dpkg-reconfigure openssh-server &>/dev/null ; /bin/systemctl restart ssh.service ; rm --force /etc/cron.d/keys'\n" > /etc/cron.d/keys
fi

# Regenerate certificates (workaround when /etc/ssl/certs/ca-certificates.crt is empty after sysprep)
/usr/sbin/update-ca-certificates
