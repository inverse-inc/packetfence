#!/usr/bin/perl

=head1 NAME

migrate.pl

=head1 DESCRIPTION

Util to migrate existing OS Active Directory configuration into PacketFence and then bind to the domain.

=cut

use lib '/usr/local/pf/lib';

use Term::ReadKey;
use pf::file_paths qw($domain_config_file);

BEGIN {
  use Log::Log4perl;
  use pf::log();
  my $log_conf = q(
  log4perl.rootLogger              = INFO, SCREEN
  log4perl.appender.SCREEN         = Log::Log4perl::Appender::Screen
  log4perl.appender.SCREEN.stderr  = 0
  log4perl.appender.SCREEN.layout  = Log::Log4perl::Layout::PatternLayout
  log4perl.appender.SCREEN.layout.ConversionPattern = %m %n
  );
  Log::Log4perl::init(\$log_conf);
}

use pf::util;
use pf::domain;
use pf::ConfigStore::Domain;

my $REALM = pf_run('grep default_realm /etc/krb5.conf | awk \'{print $3}\'');
chomp($REALM);
my $WORKGROUP = pf_run('grep workgroup /etc/samba/smb.conf | awk \'{print $3}\'');
chomp($WORKGROUP);
my $SERVER = pf_run('grep admin_server /etc/krb5.conf | head -1 | awk \'{print $3}\'');
chomp($SERVER);
my $NAMESERVER = pf_run('grep nameserver /etc/resolv.conf | head -1 | awk \'{print $2}\'');
chomp($NAMESERVER);

print "CAUTION: This account needs to have the rights to bind a new server on the domain. \n";
print "What is the username to bind this server on the domain : ";
my $user =  <STDIN>;
chomp ($user);

print "Password: ";
ReadMode('noecho');
my $password =  <STDIN>;
ReadMode(0);
chomp ($password);
print "\n";

print "What is this server's name in your Active Directory ? ";
my $server_name = <STDIN>;
chomp($server_name);

my $config = {workgroup => $WORKGROUP, dns_name => $REALM, dns_servers => $NAMESERVER, ad_server => $SERVER, server_name => $server_name};
my $cs = pf::ConfigStore::Domain->new;
$cs->update_or_create($WORKGROUP, $config);
$cs->commit();

$config{bind_dn} = $user;
$config{bind_pass} = $password;

print "Configuring realm : '$REALM' \n";
print "Configuring workgroup : '$WORKGROUP' \n";
print "Configuring with AD server : '$SERVER' \n";
print "Configuring with nameserver : '$NAMESERVER' \n";
print "Configuring with user : '$user' \n";
print "Configuring with server name : '$server_name' \n";

print "Are these settings fine ? This is your last chance before the domain bind. (y/n)";
my $confirm = <STDIN>;
chomp($confirm);
if($confirm eq 'y'){
  pf_run('cp /etc/krb5.conf /etc/krb5.conf.pf_backup');
  pf::domain::regenerate_configuration();
  my $output = pf::domain::join_domain($WORKGROUP, $config);
  # we remove the password after the configuration
  print "Done. If there were any issues joining the domain, you can now use the web interface to fix the issues (Configuration->Domains) \n";
}
else{
  print "Please re-run the script again or configure the domain directly through the admin UI in 'Configuration->Domain' \n";
}

pf_run("chown pf.pf $domain_config_file");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut


