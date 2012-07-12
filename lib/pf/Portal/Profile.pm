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

use Log::Log4perl;

use pf::config;

=head1 METHODS

=over

=item new

No one should call ->new by himself. L<pf::Portal::ProfileFactory> should
be used instead.

=cut
sub new {
    my ( $class, $args_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->debug("instantiating new ". __PACKAGE__ . " object");

    # XXX if complex init is required, it should be done in a sub and the 
    # below should be kept for the simple parameters using an hashref slice

    # prepending all parameters in hashref with _ (ex: logo => a.jpg becomes _logo => a.jpg)
    %$args_ref = map { '_'.$_ => $args_ref->{$_} } keys %$args_ref;

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

=item getLogo

Returns the logo for the current captive portal profile.

=cut
sub getLogo {
    my ($self) = @_;
    return $self->{'_logo'};
}

=item getAuth

Returns the configured allowed authentication methods for the current captive portal profile.

=cut
sub getAuth {
    my ($self) = @_;
    return $self->{'_auth'};
}

=item getGuestSelfReg

Returns either enabled or disabled depending on if the current captive portal profile allows guest self-registration.

=cut
sub getGuestSelfReg {
    my ($self) = @_;
    return $self->{'_guest_self_reg'};
}

=item getGuestModes

Returns the available enabled modes for guest self-registration for the current captive portal profile.

=cut
sub getGuestModes {
    my ($self) = @_;
    return $self->{'_guest_modes'};
}

=item getGuestCategory

Returns the category that should be assigned to guests who self-registers themselves on the current captive portal profile.

=cut
sub getGuestCategory {
    my ($self) = @_;
    return $self->{'_guest_category'};
}

=item getTemplatePath

Returns the path for custom templates for the current captive portal profile.

Relative to html/captive-portal/templates/

=cut
sub getTemplatePath {
    my ($self) = @_;
    return $self->{'_template_path'};
}

=item getBillingEngine

Returns either enabled or disabled according to the billing engine state for the current captive portal profile.

=cut
sub getBillingEngine {
    my ($self) = @_;
    return $self->{'_billing_engine'};
}

=item getDefaultAuth

Returns the default authentication for the current captive portal profile.

=cut
sub getDefaultAuth {
    my ($self) = @_;
    return $self->{'_default_auth'};
}

=item getCategory

Returns the default category for the current captive portal profile.

=cut
sub getCategory {
    my ($self) = @_;
    return $self->{'_category'};
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
