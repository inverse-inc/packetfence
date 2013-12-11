#!/usr/bin/perl
use lib qw(/usr/local/pf/lib);

package pf::dump;
use base qw(pf::cmd::subcmd);

=head1 NAME

dump add documentation

=head1 SYNOPSIS

dump.pl <config|floatingdevices|profiles_filters|profiles|sources>

=head1 DESCRIPTION

dump

=cut


package pf::dump::config;
use base qw(pf::cmd);
use Data::Dumper;

sub _run {
    require pf::config;
    print Dumper(\%pf::config::Config);
}


package pf::dump::floatingdevices;
use base qw(pf::cmd);
use Data::Dumper;

sub _run {
    require pf::config;
    print Dumper(\%pf::config::ConfigFloatingDevices);
}

package pf::dump::profiles;
use base qw(pf::cmd);
use Data::Dumper;

sub _run {
    require pf::config;
    print Dumper(\%pf::config::Profiles_Config);
}


package pf::dump::profiles_filters;
use base qw(pf::cmd);
use Data::Dumper;

sub _run {
    require pf::config;
    print Dumper(\%pf::config::Profile_Filters);
}

package pf::dump::sources;
use base qw(pf::cmd);
use Data::Dumper;

sub _run {
    require pf::authentication;
    print Dumper(\@pf::authentication::authentication_sources);
}

package main;
use strict;
use warnings;
use lib qw(/usr/local/pf/lib);

exit pf::dump->new({args => \@ARGV})->run();


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

