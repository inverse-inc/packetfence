package pfconfig::namespaces::resource::guest_self_registration;

=head1 NAME

pfconfig::namespaces::resource::guest_self_registration

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::guest_self_registration

=cut

use strict;
use warnings;

use pf::util qw(is_in_list);
use pf::constants;
use pf::constants::config;
use List::MoreUtils qw(none any);

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;
    $self->{_authentication_config} = $self->{cache}->get_cache('config::Authentication');
}

sub build {
    my ($self) = @_;
    my %guest_self_registration = ();

    $self->{Profiles_Config} = $self->{cache}->get_cache('config::Profiles');
    my %Profiles_Config = %{ $self->{Profiles_Config} };
    $self->{guest_self_registration} = \%guest_self_registration;
    while ( my ( $id, $profile ) = each %Profiles_Config ) {
        my $guest_modes = $self->_guest_modes_from_sources( $profile->{sources} );
        $profile->{guest_modes} = $guest_modes;
        $self->_set_guest_self_registration($guest_modes);
    }
    return $self->{guest_self_registration};
}

sub _set_guest_self_registration {
    my ( $self, $modes ) = @_;
    for my $mode (
        $pf::constants::config::SELFREG_MODE_EMAIL,    $pf::constants::config::SELFREG_MODE_SMS,
        $pf::constants::config::SELFREG_MODE_SPONSOR,  $pf::constants::config::SELFREG_MODE_GOOGLE,
        $pf::constants::config::SELFREG_MODE_FACEBOOK, $pf::constants::config::SELFREG_MODE_GITHUB,
        $pf::constants::config::SELFREG_MODE_LINKEDIN, $pf::constants::config::SELFREG_MODE_WIN_LIVE,
        $pf::constants::config::SELFREG_MODE_TWITTER,
        )
    {
        $self->{guest_self_registration}{$mode} = $TRUE
            if is_in_list( $mode, $modes );
    }
}

sub _guest_modes_from_sources {
    my ( $self, $sources ) = @_;
    $sources ||= [];
    my %modeClasses = (
        external => undef,
    );
    my %is_in = map { $_ => undef } @$sources;
    my @guest_modes
        = map { lc( $_->{type} ) }
        grep { exists $is_in{ $_->{id} } && exists $modeClasses{ $_->{class} } }
        @{ $self->{_authentication_config}->{authentication_sources} };

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

