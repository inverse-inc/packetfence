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

# XXX incomplete
sub instantiate {
    my ( $self, $mac, $profile_type ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

#    $logger->debug("creating new portal profile of type $profile_type");
    # XXX handles only default profile for now
    # XXX add complex configuration loading and returning here, then add
    #     getters in ::Profile. Configuration should stay in pf::config
    #     and we only consume it especially since we will support config
    #     reload in there in the future
    # XXX also take the given mac and lookup the SSID on it and return proper
    #     portal object
    # Since we apply portal profiles based on the SSID, we check the last_ssid for the given MAC and try to match
    # a portal profile using the previously fetched filters. If no match, we instantiate the default portal profile
    my $node_info = node_view($mac);
    my @filter_ids = ((map { "$_:" . $node_info->{"last_$_"}  } qw(ssid vlan)), @{$node_info}{'last_ssid','last_vlan'});
    my $filtered_profile =
        first {exists $Profiles_Config{$_}}
        map { $Profile_Filters{$_}  }
          grep { defined $_ && exists $Profile_Filters{$_}  } #
          @filter_ids;

    return pf::Portal::Profile->new(_custom_profile($filtered_profile)) if $filtered_profile;

    return pf::Portal::Profile->new(_default_profile());
}

sub _default_profile { return {%{$Profiles_Config{default} }, name => 'default' ,template_path => '/'}; }

sub _custom_profile {
    my ($name) = @_;
    my $defaults = _default_profile();
    my $profile = $Profiles_Config{$name};
    my %results = (
        'name' => $name,
        'template_path' => $name,
        'description' => $profile->{'description'} || '',
        map { $_ =>  ($profile->{$_} || $defaults->{$_} ) }
        qw (logo guest_self_reg guest_modes sources billing_engine filter)
    );
    $results{guest_modes} = _guest_modes_from_sources($results{sources});
    return \%results;
}

sub _guest_modes_from_sources {
    my ($sources) = @_;
    $sources ||= [];
    my %is_in = map {$_ => undef } @$sources;
    my @guest_modes = map { lc($_->type)} grep { exists $is_in{$_->id} && $_->class eq 'external'} @authentication_sources;
}

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
