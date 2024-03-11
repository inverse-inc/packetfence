#!/usr/bin/perl

=head1 NAME

to-12.0-authentication -

=head1 DESCRIPTION

to-12.0-authentication

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use List::Util qw(all);
my @old_values = qw(100056 100057 100061 100058 100059 100060 100062 100063 100071 100064 100116 100066 100117 100112 100067 100065 100068 100069 100070 100118 100115 100072 100073 100074 100075 100076 100077 100085 100086 100080 100079 100081 100083 100082 100084 100087 100088 100111 100089 100090 100091 100092 100093 100094 100095 100096 100098 100097 100099 100100 100101 100113 100102 100103 100104 100106 100105 100107 100108 100109 100114 100110 100078 100119 100120 100121 100122 100123 100124 100125 100126 100127 100128);
use pf::file_paths qw($authentication_config_file);
use pf::IniFiles;

my $example_file = $authentication_config_file . '.example';
my $example_ini = pf::IniFiles->new( -file => $example_file);
my $ini = pf::IniFiles->new( -file => $authentication_config_file);
my $new_value = $example_ini->val('sms', 'sms_carriers');
my @new_values = split /\s*,\s*/, $new_value;

my $i = 0;
for my $section ( grep { /^\S+$/ } $ini->Sections()) {
    my $type = $ini->val($section, 'type');
    next if !defined $type || $type ne 'SMS';
    my $sms_carriers = $ini->val($section, 'sms_carriers');
    my @sms_carriers =  split /\s*,\s*/, $sms_carriers;
    next if scalar @old_values != @sms_carriers;

    my %sms_carriers = map { $_ => 1 } @sms_carriers;
    next unless all { exists $sms_carriers{$_} } @old_values;

    print "Updating $section\n";
    $ini->setval($section, 'sms_carriers', join(',', $sms_carriers, grep { !exists $sms_carriers{$_} } @new_values ));
    $i |= 1;
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

