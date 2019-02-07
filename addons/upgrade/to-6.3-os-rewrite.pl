#!/usr/bin/perl

=head1 NAME

to-6.3-os-rewrite.pl - 3.5 upgrade script to rewrite the OS lists to use Fingerbank IDs

=head1 USAGE

Basically: 

  addons/upgrade/to-6.3-os-rewrite.pl

=head1 DESCRIPTION

Migrates the oses value in provisioning.conf and scan.conf to Fingerbank IDs

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';
use Config::IniFiles;
use pf::file_paths qw($provisioning_config_file $scan_config_file);
use fingerbank::Constant;
use Data::Dumper;
use Switch;
use pf::util;

run_as_pf();

sub id_from_name {
    my ($os) = @_;
    my $id;
    switch($os) {
        case "Windows" {
            $id = $fingerbank::Constant::PARENT_IDS{WINDOWS}; 
        }
        case "Macintosh" {
            $id = $fingerbank::Constant::PARENT_IDS{MACOS};
        }
        case "Generic Android" {
            $id = $fingerbank::Constant::PARENT_IDS{ANDROID};
        }
        case "Apple iPod, iPhone or iPad" {
            $id = $fingerbank::Constant::PARENT_IDS{IOS};
        }
    };
    return $id;
}

my $file_suffix = ".new";

my $cfg = Config::IniFiles->new( -file => $provisioning_config_file);

if(defined($cfg)) {
    foreach my $prov ($cfg->Sections()) {
        next unless($cfg->val($prov, 'oses'));
        print "=" x 25 . "\n";
        my @new_oses;
        foreach my $os ($cfg->val($prov, 'oses')){
            my $id = id_from_name($os);
            if(defined($id)){
                push @new_oses, $id if(defined($id));
            }
            else {
                print STDERR "!!!!!! - Couldn't match OS $os in section $prov, please adjust the configuration manually... \n";
            }
        }
        print "Replacing : " . join(',', "'".$cfg->val($prov, 'oses')."'") . " by : " . join(',',@new_oses)." in section $prov \n";
        $cfg->setval($prov, 'oses', join(',',@new_oses));
    }

    $cfg->WriteConfig($provisioning_config_file.$file_suffix) or die("!!!!!! - Can't write '$provisioning_config_file$file_suffix'. Please validate the permissions and run this again");
}
else {
    `touch $provisioning_config_file$file_suffix`;
}

$cfg = Config::IniFiles->new( -file => $scan_config_file);

if(defined($cfg)) {
    foreach my $scan ($cfg->Sections()) {
        next unless($cfg->val($scan, 'oses'));
        print "=" x 25 . "\n";
        my @new_oses;
        foreach my $os (split(/\s*,\s*/, $cfg->val($scan, 'oses'))){
            my $id = id_from_name($os);
            if(defined($id)){
                push @new_oses, $id if(defined($id));
            }
            else {
                print STDERR "!!!!!! - Couldn't match OS $os in section $scan, please adjust the configuration manually... \n";
            }
        }
        print "Replacing : " . join(',', "'".$cfg->val($scan, 'oses')."'") . " by : " . join(',',@new_oses)." in section $scan \n";
        $cfg->setval($scan, 'oses', join(',',@new_oses));
    }
    
    $cfg->WriteConfig($scan_config_file.$file_suffix) or die("!!!!!! - Can't write '$scan_config_file$file_suffix'. Please validate the permissions and run this again");
}
else {
    `touch $scan_config_file$file_suffix`;
}

print "=" x 25 . "\n";
print "Done, now is time to validate the files content and copy them over the original configuration.\n";

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

