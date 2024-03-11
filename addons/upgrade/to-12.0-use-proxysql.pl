#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-12.0-use-proxysql

=cut

=head1 DESCRIPTION

Use proxysql instead of haproxy-db

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($pf_config_file $pf_default_file);
use pf::util;
run_as_pf();

my $pf_ini = pf::IniFiles->new(-file => $pf_config_file, -allowempty => 1);
my $pfconfig_ini = pf::IniFiles->new(-file => '/usr/local/pf/conf/pfconfig.conf', -allowempty => 1);

unless ($pf_ini) {
    exit;
}

if (!$pf_ini->exists('database', 'host')) {
    exit;
}

my $db_pf = $pf_ini->val('database', 'host');
my $db_pfconfig = $pfconfig_ini->val('mysql', 'host');

if ($db_pf eq '127.0.0.1' || $db_pfconfig eq '127.0.0.1') {
    $pf_ini->newval('database', 'host', '100.64.0.1');
    $pf_ini->newval('database', 'port', '6033');
    $pf_ini->RewriteConfig();
    $pfconfig_ini->newval('mysql', 'host', '100.64.0.1');
    $pfconfig_ini->newval('mysql', 'port', '6033');
    $pfconfig_ini->RewriteConfig();
} else {
    print "Nothing to do \n";
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

