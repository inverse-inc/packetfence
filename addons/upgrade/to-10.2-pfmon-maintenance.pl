#!/usr/bin/perl

=head1 NAME

pfmon_to_maintenance -

=head1 DESCRIPTION

pfmon_to_maintenance

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::constants::config;
use pf::file_paths qw(
    $conf_dir
    $cron_config_file
);
use File::Spec::Functions;
use File::Copy;

my $pfmon_config_file_rpmsave = catfile($conf_dir, "pfmon.conf.rpmsave");
my $pfmon_config_file = catfile($conf_dir, "pfmon.conf");
my $default_cronspec = '@every 1m';
my $maintenance = pf::IniFiles->new();

if( ! -f $pfmon_config_file ) {
    if(-f $pfmon_config_file_rpmsave) {
        print "Copying pfmon.conf.rpmsave to pfmon.conf\n";
        copy($pfmon_config_file_rpmsave, $pfmon_config_file) or die "Copy failed: $!";
    }
    else {
        print "No settings to migrate from pfmon.conf or pfmon.conf.rpmsave\n";
        exit;
    }
}

my $pfmon = pf::IniFiles->new( -file => $pfmon_config_file, -allowempty => 1);

for my $section ($pfmon->Sections) {
    for my $p ($pfmon->Parameters($section)) {
        my $value = $pfmon->val($section, $p);
        my @comments = $pfmon->GetParameterComment($section, $p);
        if ($p eq 'interval') {
            @comments = (
                '',
                'schedule',
                '',
                'The schedule of task'
            );
            if ($value =~ /^0($pf::constants::config::TIME_MODIFIER_RE)/) {
                $maintenance->setval($section, 'status', 'disabled');
            }

            $value = interval_to_cronspec($value);
            $p = 'schedule';
        }
        addNew($maintenance, $section, $p, $value, @comments);
    }
}

sub interval_to_cronspec {
    my ($date) = @_;
    return $default_cronspec if ( !defined($date) );
    if ( $date =~ /^\d+$/ ) {
        return "\@every ${date}s";
    }
    my ( $num, $modifier ) =
      $date =~ /^(\d+)($pf::constants::config::TIME_MODIFIER_RE)/
      or return $default_cronspec;

    if ($num == 0) {
        return $default_cronspec;
    }

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

    return $default_cronspec;
}

sub addNew {
    my ($ci, $s, $p, $v, @desc) = @_;
    $ci->AddSection($s);
    $ci->newval($s, $p, $v);
    $ci->SetParameterComment($s, $p, @desc)
}

$maintenance->WriteConfig($cron_config_file);

print "Done migrating configuration\n";

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

