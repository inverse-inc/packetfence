#!/usr/bin/perl

=head1 NAME

to-10.3-roles-acls.pl -

=head1 DESCRIPTION

Migrate the ACLs from the switches to all.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use Data::Dumper;
use pf::file_paths qw(
    $switches_config_file
    $roles_config_file
);
use Term::Cap;
my $terminal = Term::Cap->Tgetent( { OSPEED => 9600 } );
my $clear_string = $terminal->Tputs('cl');
my $switch_ini = pf::IniFiles->new(-file => $switches_config_file, -allowempty => 1);
my $roles_ini = pf::IniFiles->new(-file => $roles_config_file, -allowempty => 1);
my $switch_ini_updated = 0;
my $roles_ini_updated = 0;
my %roles;
my %switches;

for my $section ($switch_ini->Sections()) {
    my @params = grep { /AccessList$/ } $switch_ini->Parameters($section);
    unless (@params) {
        next;
    }

    for my $p (@params) {
        $p =~ /^(.*)AccessList$/;
        my $r = $1;
        my $acls = join("\n", $switch_ini->val($section, $p));
        $roles{$r}{$section} = $acls;
        $switch_ini->delval($section, $p);
        $switches{$section}{$r} = $acls;
    }
    
    $switch_ini_updated |= 1;
}

my @switches = keys %switches;
if (@switches) {
    while(1) {
        my $i = 0;
        my $msg = join("\n", "0) Choose ACLs mappings per role", "- Choose the switch for ACL mapping", (map {$i++; "$i) $_ "} @switches), "");
        print $clear_string;
        print "$msg\n";
        my $count = @switches;
        my $index = prompt("Choose a number from 0 - $count");
        if ("$index" eq '0') {
            for my $role (keys %roles) {
                my $data = $roles{$role};
                my @switches = keys %$data;
                my $i = 0;
                my $msg = join("\n", "0) Skip " , map {$i++; "$i) $_ "} @switches);
                print $clear_string;
                print "$msg\n";
                my $count = @switches;
                print "Choose a number from 0 - $count\n";
                my $index = prompt("For the role '$role' which switch to use for the ACL");
                if ("$index" eq '0') {
                    next;
                }
                $index+=0;
                unless ($index && $index >=1 && $index <= @switches) {
                    prompt("'$index' is an invalid choice press Enter (or Return) to retry");
                    redo;
                }

                my $switch = $switches[$index-1];
                $roles_ini->newval($role, 'acls', $data->{$switch});
                $roles_ini_updated |= 1;
            }
        } else {
            unless ($index && $index >=0 && $index <= @switches) {
                prompt("'$index' is an invalid choice press Enter (or Return) to retry");
                redo;
            }

            my $switch = $switches[$index-1];
            while (my ($role, $acl) = each %{$switches{$switch}}) {
                $roles_ini->newval($role, 'acls', $acl);
                $roles_ini_updated |= 1;
            }
        }
        last;
    }
}

if ($switch_ini_updated == 0 && $roles_ini_updated == 0) {
    print "Nothing to be done\n";
} else {
    if ($switch_ini_updated) {
        $switch_ini->RewriteConfig();
    }
    if ($roles_ini_updated) {
        $roles_ini->RewriteConfig();
    }
    print "All done\n";
}

sub prompt {
    my ($prompt, $default) = @_;
    if (defined $default) {
        $prompt .= "[$default]";
    }

    print $prompt, ": ";
    $| = 1; # Force a flush
    my $input = <STDIN>;
    chomp($input);
    if (length($input) == 0 && defined $default) {
        $input = $default;
    }

    return $input;
}

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
