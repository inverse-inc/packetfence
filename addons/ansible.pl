#!/usr/bin/perl
=head1 NAME

ansible.pl - Generate Ansible configuration to push ACLs manually

=head1 DESCRIPTION

Generate ansible configuration to configure switches.

=cut

require 5.8.5;
use strict;
use warnings;
use FindBin;
use constant {
    LIB_DIR   => $FindBin::Bin . "/../lib",
    LIB_PERL5_DIR   => $FindBin::Bin . "/../lib_perl/lib/perl5",
};

use lib (LIB_DIR, LIB_PERL5_DIR);

use pf::config qw(%ConfigRoles);
use Template;
use Switch;

use pf::file_paths qw(
    $conf_dir
    $var_dir
);

use pf::config::cluster;
use pf::SwitchFactory;

tie my %SwitchConfig, 'pfconfig::cached_hash', "config::Switch($host_id)";
my $count = 0;

my %vars;

my $tt = Template->new(
    ABSOLUTE => 1,
);

if (! -e "$var_dir/conf/pfsetacls") {
    mkdir("$var_dir/conf/pfsetacls") or die "Can't create $var_dir/conf/pfsetacls/:$!";
}

foreach my $switch_id (keys(%SwitchConfig)) {
    next if ($switch_id =~ /^group / or $switch_id =~ /.*\/.*/ or $switch_id =~ /.*\:.*/ or $switch_id eq 'default' or $switch_id eq '100.64.0.1' or $switch_id eq '127.0.0.1');
    my $switch = pf::SwitchFactory->instantiate($switch_id);
    if ($switch) {
        $switch->generateAnsibleConfiguration();
    }
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
