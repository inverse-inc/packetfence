package pf::Portal::Profile;

=head1 NAME

pf::Portal::Profile

=cut

=head1 DESCRIPTION

pf::Portal::Profile wraps captive portal configuration in a way that we can
provide several differently configured (behavior and template) captive
portal from the same server.

=cut

use strict;
use warnings;

use List::Util qw(first);
use pf::config qw($TRUE $FALSE);
use pf::log;

=head1 METHODS

=over

=item new

No one should call ->new by himself. L<pf::Portal::ProfileFactory> should
be used instead.

=cut

sub new {
    my ( $class, $args_ref ) = @_;
    my $logger = get_logger();
    $logger->debug("instantiating new ". __PACKAGE__ . " object");

    # XXX if complex init is required, it should be done in a sub and the
    # below should be kept for the simple parameters using an hashref slice

    # prepending all parameters in hashref with _ (ex: logo => a.jpg becomes _logo => a.jpg)
    %$args_ref = map { "_".$_ => $args_ref->{$_} } keys %$args_ref;

    my $self = bless $args_ref, $class;

    return $self;
}

=item getName

Returns the name of the captive portal profile.

=cut

sub getName {
    my ($self) = @_;
    return $self->{'_name'};
}

*name = \&getName;

=item getLogo

Returns the logo for the current captive portal profile.

=cut

sub getLogo {
    my ($self) = @_;
    return $self->{'_logo'};
}

*logo = \&getLogo;

=item getGuestSelfReg

Returns either enabled or disabled depending on if the current captive portal profile allows guest self-registration.

=cut

sub getGuestSelfReg {
    my ($self) = @_;
    return $self->{'_guest_self_reg'};
}

*guest_self_reg = \&getGuestSelfReg;

=item getGuestModes

Returns the available enabled modes for guest self-registration for the current captive portal profile.

=cut

sub getGuestModes {
    my ($self) = @_;
    return $self->{'_guest_modes'};
}

*guest_modes = \&getGuestModes;

=item getTemplatePath

Returns the path for custom templates for the current captive portal profile.

Relative to html/captive-portal/templates/

=cut

sub getTemplatePath {
    my ($self) = @_;
    return $self->{'_template_path'};
}

*template_path = \&getTemplatePath;

=item getBillingEngine

Returns either enabled or disabled according to the billing engine state for the current captive portal profile.

=cut

sub getBillingEngine {
    my ($self) = @_;
    return $self->{'_billing_engine'};
}

*billing_engine = \&getBillingEngine;

=item getDescripton

Returns either enabled or disabled according to the billing engine state for the current captive portal profile.

=cut

sub getDescripton {
    my ($self) = @_;
    return $self->{'_description'};
}

*description = \&getDescripton;

=item getSources

Returns the authentication sources IDs for the current captive portal profile.

=cut

sub getSources {
    my ($self) = @_;
    return $self->{'_sources'};
}

*sources = \&getSources;

=item getSourceByType

Returns the first source ID for the requested source type for the current captive portal profile.

=cut

sub getSourceByType {
    my ($self, $type) = @_;
    my $result;
    if ($type) {
        $type = uc($type);
        $result = first {uc(pf::authentication::getAuthenticationSource($_)->{'type'}) eq $type} @{$self->getSources()};
    }

    unless ($result) {
        my $logger = get_logger();
        $logger->error(sprintf("No source of type '%s' defined for profile '%s'", $type, $self->getName));
    }

    return $result;
}

=item guestRegistrationOnly

Returns true if the profile only uses "sign-in" authentication sources (SMS, email or sponsor).

=cut

sub guestRegistrationOnly {
    my ($self) = @_;

    my %registration_types =
      (
       pf::Authentication::Source::EmailSource->meta->get_attribute('type')->default => undef,
       pf::Authentication::Source::SMSSource->meta->get_attribute('type')->default => undef,
       pf::Authentication::Source::SponsorEmailSource->meta->get_attribute('type')->default => undef,
      );

    my $result = first { !exists $registration_types{$_} }
      map { pf::authentication::getAuthenticationSource($_)->{'type'} } @{$self->getSources()};

    return ($result? $FALSE : $TRUE);
}

=back

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
