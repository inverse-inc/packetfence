#!/usr/bin/perl
use lib qw(/usr/local/pf/lib);
use Data::Dumper;

package pf::dump;
use base qw(pf::cmd::subcmd);

=head1 NAME

dump add documentation

=head1 SYNOPSIS

dump.pl <apachefilters|config|doc_config|floatingdevices|profiles_filters|profiles|sources|switch <id>|switches|admin_roles|chiconfig>

=head1 DESCRIPTION

dump

=cut

package pf::dump::cmd;
use base qw(pf::cmd);
use Module::Loaded qw(mark_as_loaded);

package pf::dump::apachefilters;
use base qw(pf::dump::cmd);
use Data::Dumper;
__PACKAGE__->mark_as_loaded();

sub _run {
    require pf::config;
    print Data::Dumper::Dumper(\%pf::config::ConfigApacheFilters);
}

package pf::dump::config;
use base qw(pf::dump::cmd);
__PACKAGE__->mark_as_loaded();

sub _run {
    require pf::config;
    print Data::Dumper::Dumper(\%pf::config::Config);
}

package pf::dump::doc_config;
use base qw(pf::dump::cmd);
__PACKAGE__->mark_as_loaded();

sub _run {
    require pf::config;
    print Data::Dumper::Dumper(\%pf::config::Doc_Config);
}


package pf::dump::floatingdevices;
use base qw(pf::dump::cmd);
__PACKAGE__->mark_as_loaded();

sub _run {
    require pf::config;
    print Data::Dumper::Dumper(\%pf::config::ConfigFloatingDevices);
}

package pf::dump::profiles;
use base qw(pf::dump::cmd);
__PACKAGE__->mark_as_loaded();

sub _run {
    require pf::config;
    print Data::Dumper::Dumper(\%pf::config::Profiles_Config);
}


package pf::dump::profiles_filters;
use base qw(pf::dump::cmd);
__PACKAGE__->mark_as_loaded();

sub _run {
    require pf::config;
    print Data::Dumper::Dumper(\%pf::config::Profile_Filters);
}

package pf::dump::sources;
use base qw(pf::dump::cmd);
__PACKAGE__->mark_as_loaded();

sub _run {
    require pf::authentication;
    print Data::Dumper::Dumper(\@pf::authentication::authentication_sources);
}

package pf::dump::switch;
use base qw(pf::dump::cmd);
__PACKAGE__->mark_as_loaded();

sub parseArgs {
    my ($self) = @_;
    return $self->args == 1;
}

sub _run {
    my ($self) = @_;
    require pf::SwitchFactory;
    print Data::Dumper::Dumper(pf::SwitchFactory->getInstance->instantiate($self->args));
}

package pf::dump::switches;
use base qw(pf::dump::cmd);
__PACKAGE__->mark_as_loaded();

sub _run {
    require pf::ConfigStore::Switch;
    print Data::Dumper::Dumper(\%pf::ConfigStore::Switch::SwitchConfig);
}

package pf::dump::chiconfig;
use base qw(pf::dump::cmd);
__PACKAGE__->mark_as_loaded();

sub _run {
    require pf::CHI;
    print Data::Dumper::Dumper(pf::CHI::chiConfigFromIniFile());
}

package pf::dump::admin_roles;
use base qw(pf::dump::cmd);
__PACKAGE__->mark_as_loaded();

sub _run {
    require pf::admin_roles;
    print Data::Dumper::Dumper(\%pf::admin_roles::ADMIN_ROLES);
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

