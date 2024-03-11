#!/usr/bin/perl

=head1 NAME

to-12.0-rename-log-files.pl

=head1 DESCRIPTION

Rename log files defined in logs= in syslog.conf

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::util;
use pf::IniFiles;
use pf::constants::config;
use pf::file_paths qw(
    $conf_dir
    $syslog_config_file
);
use List::MoreUtils qw(any);

run_as_pf();

my %remap = (
    'mariadb_error.log'           => 'mariadb.log',
    'httpd.aaa.access'            => 'httpd.apache',
    'httpd.aaa.error'             => 'httpd.apache',
    'httpd.portal.error'          => 'httpd.apache',
    'httpd.portal.access'         => 'httpd.apache',
    'httpd.portal.catalyst'       => 'httpd.apache',
    'httpd.proxy.error'           => 'httpd.apache',
    'httpd.proxy.access'          => 'httpd.apache',
    'httpd.webservices.error'     => 'httpd.apache',
    'httpd.webservices.access'    => 'httpd.apache',
    'httpd.api-frontend.access'   => 'httpd.apache',
);

my $ini = pf::IniFiles->new( -file => $syslog_config_file, -allowempty => 1);
my $i = 0;

for my $section ($ini->Sections()) {
    if (my $logs = $ini->val($section, 'logs')) {
        $logs = [ split(/,/, $logs) ];

        if(any {exists $remap{$_}} @$logs) {
            print "Renaming log files in section $section in file $syslog_config_file\n";
            $logs = [ map { exists($remap{$_}) ? $remap{$_} : $_ } @$logs ];
            $ini->setval($section, 'logs', join(',', @$logs));
            $i |= 1;
        }
    }
}
if ($i) {
    $ini->RewriteConfig();
    print "All done\n";
} else {
    print "Nothing to be done\n";
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

