package pf::Portal::ProfileFactory;

=head1 NAME

pf::Portal::ProfileFactory - Factory to construct special
pf::Portal::Profile objects with complex initialization

=head1 SYNOPSIS

This module is meant to encapsulate the coupling between the configuration
and the actual pf::Portal::Profile objects. Reading and parsing the
configuration containing all the necessary information needed to actually
instantiate the objects.

=cut

use strict;
use warnings;

use Log::Log4perl;

use pf::config;
use pf::node;
use pf::authentication;
use pf::Portal::Profile;
use List::Util qw(first);

=head1 SUBROUTINES

=head2 instantiate

Create a new pf::Portal::Profile instance based on parameters given.

=cut

sub instantiate {
    my ( $self, $mac, $options ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $options ||= {};
    if (defined($options->{'portal'})) {
        $logger->trace("Instantiate profile ".$options->{'portal'});
        return $self->_from_profile($options->{'portal'});
    }
    # We apply portal profiles based on the uri, SSID, VLAN and switch. We check the last_(ssid|vlan|switch) for the given MAC
    # and try to match a portal profile using the previously fetched filters.
    # If no match, we instantiate the default portal profile.
    my $node_info = node_view($mac) || {};
    $node_info = { %$node_info, %$options } ;
    my $filter = first { $_->match($node_info) } @Profile_Filters;
    my $profile_name = $filter ? $filter->profile : 'default';
    $logger->trace("Instantiate profile $profile_name");
    return $self->_from_profile($profile_name);
}

=head2 _from_profile

Massages the profile values before creating the object

=cut

sub _from_profile {
    my ($self,$profile_name) = @_;
    my $profile_ref    = $Profiles_Config{$profile_name};
    my %profile        = %$profile_ref;
    my $sources        = $profile{'sources'};
    $profile{'name'}   = $profile_name;
    unless ( defined $sources && ref($sources) eq 'ARRAY' && @$sources ) {
        $profile{'sources'} = $sources = [
            map    { $_->id }
              grep { $_->class ne 'exclusive' }
              @{ pf::authentication::getAllAuthenticationSources() }
        ];
    }
    $profile{guest_modes} = _guest_modes_from_sources($sources);
    $profile{chained_guest_modes} = _chained_guest_modes_from_sources($sources);
    $profile{name} = $profile_name;
    $profile{template_path} = $profile_name;
    return pf::Portal::Profile->new( \%profile );
}

=head2 _guest_modes_from_sources

Extract the guest modes from the sources

=cut

sub _guest_modes_from_sources {
    my ($sources) = @_;
    $sources ||= [];
    my %modeClasses = (
        external  => undef,
        exclusive => undef,
    );
    my %is_in = map { $_ => undef } @$sources;
    my @guest_modes =
      map { lc($_->type) }
        grep { exists $is_in{$_->id} && exists $modeClasses{$_->class} }
          @{pf::authentication::getAllAuthenticationSources()};

    return \@guest_modes;
}


=head2 _chained_guest_modes_from_sources

Extract the guest modes from the chained sources

=cut

sub _chained_guest_modes_from_sources {
    my ($sources) = @_;
    $sources ||= [];
    my %modeClasses = (
        external  => undef,
        exclusive => undef,
    );
    my %is_in = map { $_ => undef } @$sources;
    my @modes = map { lc($_->getChainedAuthenticationSourceObject->type)} grep { exists $is_in{$_->id} && $_->type eq 'Chained'} @{pf::authentication::getAllAuthenticationSources()};

    return \@modes;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

