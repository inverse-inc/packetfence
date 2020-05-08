#!/usr/bin/perl

=head1 NAME

pfmon_to_maintenance -

=head1 DESCRIPTION

pfmon_to_maintenance

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::constants::config;
use pf::file_paths qw(
    $pfmon_default_config_file
    $maintenance_default_config_file
);


my $pfmon = pf::IniFiles->new( -file => $pfmon_default_config_file);
my $maintenance = pf::IniFiles->new();
my %skip = (
    type => undef,
    status => undef,
    interval => undef,
    description => undef,
);

for my $section ($pfmon->Sections) {
    addNew($maintenance, $section, 'type', $pfmon->val($section, 'type', $section), 'Task type');
    addNew($maintenance, $section, 'status', $pfmon->val($section, 'status', 'enabled'), 'If the task is enabled');
    addNew($maintenance, $section, 'description', $pfmon->val($section, 'description', 'Task description'), 'The description of task');
    addNew($maintenance, $section, 'schedule', interval_to_cronspec($pfmon->val($section, 'interval')), 'The schedule of task');
    for my $p ($pfmon->Parameters($section)) {
        next if exists $skip{$p};
        $maintenance->newval($section, $p, $pfmon->val($section, $p));
        $maintenance->SetParameterComment($section, $p, $pfmon->GetParameterComment($section, $p));
    }
}

sub interval_to_cronspec {
    my ($date) = @_;
    return '@every 1m' if ( !defined($date) );
    if ( $date =~ /^\d+$/ ) {
        return "\@every ${date}s";
    }
    my ( $num, $modifier ) =
      $date =~ /^(\d+)($pf::constants::config::TIME_MODIFIER_RE)/
      or return (0);

    if ( $modifier eq "s" ) {
        return "\@every ${num}s";
    }
    elsif ( $modifier eq "m" ) {
        return "\@every ${num}m";
    }
    elsif ( $modifier eq "h" ) {
        return "\@every ${num}h";
    }
    elsif ( $modifier eq "D" ) {
        $num *= 24;
        return "\@every ${num}h";
    }
    elsif ( $modifier eq "W" ) {
        $num *= 24 * 7;
        return "\@every ${num}h";
    }
    elsif ( $modifier eq "M" ) {
        $num *= 24 * 30;
        return "\@every ${num}h";
    }
    elsif ( $modifier eq "Y" ) {
        $num *= 24 * 365;
        return "\@every ${num}h";
    }

    return "\@every 1m";
}

sub addNew {
    my ($ci, $s, $p, $v, $desc) = @_;
    $ci->AddSection($s);
    $ci->newval($s, $p, $v);
    $ci->SetParameterComment($s, $p, '', $p, '', $desc)
}

$maintenance->WriteConfig($maintenance_default_config_file);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

