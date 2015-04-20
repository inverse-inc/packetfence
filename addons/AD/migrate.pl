#!/usr/bin/perl

use lib '/usr/local/pf/lib';

use pf::util;

my $REALM = pf_run('grep default_realm /etc/krb5.conf | awk \'{print $3}\'');
chomp($REALM);
my $WORKGROUP = pf_run('grep workgroup /etc/samba/smb.conf | awk \'{print $3}\'');
chomp($WORKGROUP);
my $SERVER = pf_run('grep admin_server /etc/krb5.conf | head -1 | awk \'{print $3}\'');
chomp($SERVER);
my $NAMESERVER = pf_run('grep nameserver /etc/resolv.conf | head -1 | awk \'{print $2}\'');
chomp($NAMESERVER);

print "Configuring realm : '$REALM' \n";
print "Configuring workgroup : '$WORKGROUP' \n";
print "Configuring with AD server : '$SERVER' \n";
print "Configuring with nameserver : '$NAMESERVER' \n";

print "CAUTION: The following information will end up in clear text in the PacketFence configuration files. We suggest you create another account to bind this server. This account needs to have the rights to bind a new server on the domain. \n";
print "What is the username to bind this server on the domain : ";
my $user =  <STDIN>; 
chomp ($user);

print "Password: ";
my $password =  <STDIN>; 
chomp ($password);


