package pf::Connection::ProfileFactory;

=head1 NAME

pf::Connection::ProfileFactory - Factory to construct special
pf::Connection::Profile objects with complex initialization

=head1 SYNOPSIS

This module is meant to encapsulate the coupling between the configuration
and the actual pf::Connection::Profile objects. Reading and parsing the
configuration containing all the necessary information needed to actually
instantiate the objects.

=cut

use strict;
use warnings;

use pf::log;

use pf::config qw(%Profiles_Config);
use pf::node;
use pf::authentication;
use pf::Connection::Profile;
use pf::filter_engine::profile;
use pf::factory::condition::profile;
use pfconfig::cached_scalar;
use List::Util qw(first);
use pf::StatsD::Timer;

=head1 SUBROUTINES

=head2 instantiate

Create a new pf::Connection::Profile instance based on parameters given.

=cut

tie our $PROFILE_FILTER_ENGINE , 'pfconfig::cached_scalar' => 'FilterEngine::Profile';

sub instantiate {
    my ( $self, $mac_or_node_obj, $options ) = @_;
    $options ||= {};
    if (defined($options->{'portal'})) {
        return $self->_from_profile($options->{'portal'});
    }
    my $node_info;
    if (ref($mac_or_node_obj)) {
        $node_info = $mac_or_node_obj;
    }
    else {
        $node_info = node_view($mac_or_node_obj) || {};
    }

    $options->{last_ip} //= pf::ip4log::mac2ip($node_info->{mac});

    $node_info = {%$node_info, %$options};

    my $profile_name = $PROFILE_FILTER_ENGINE->match_first($node_info);
    my $instance = $self->_from_profile($profile_name);
    return $instance;
}


=head2 _from_profile

Massages the profile values before creating the object

=cut

sub _from_profile {
    my $timer = pf::StatsD::Timer->new({level => 7});
    my ($self,$profile_name) = @_;
    my $logger = get_logger();
    $profile_name = "default" unless exists $Profiles_Config{$profile_name};
    $logger->info("Instantiate profile $profile_name");
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
    $profile{name} = $profile_name;
    my $instance =  pf::Connection::Profile->new( \%profile );
    return $instance;
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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

