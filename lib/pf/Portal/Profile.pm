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
use List::MoreUtils qw(all none any);
use pf::config qw($TRUE $FALSE);
use pf::util;
use pf::log;
use pf::node;
use pf::factory::provisioner;
use pf::os;

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

=item getLocales

Returns the locales for the profile.

=cut

sub getLocales {
    my ($self) = @_;
    return grep { $_ } @{$self->{'_locale'}};
}

*locale = \&getLocales;

sub getRedirectURL {
    my ($self) = @_;
    return $self->{'_redirecturl'};
}

*redirecturl = \&getRedirectURL;

sub forceRedirectURL {
    my ($self) = @_;
    return $self->{'_always_use_redirecturl'};
}

*always_use_redirecturl = \&forceRedirectURL;

=item getSources

Returns the authentication sources IDs for the current captive portal profile.

=cut

sub getSources {
    my ($self) = @_;
    return $self->{'_sources'};
}

*sources = \&getSources;

=item getMandatoryFields

Returns the mandatory fields for the profile

=cut

sub getMandatoryFields {
    my ($self) = @_;
    return $self->{'_mandatory_fields'};
}

*mandatoryFields = \&getMandatoryFields;

sub getProvisioners {
    my ($self) = @_;
    return $self->{'_provisioners'};
}

=item getSourcesAsObjects

Returns the authentication sources objects for the current captive portal profile.

=cut

sub getSourcesAsObjects {
    my ($self) = @_;
    return grep { defined $_ } map { pf::authentication::getAuthenticationSource($_) } @{$self->getSources()};
}

=item getInternalSources

Returns the internal authentication sources objects for the current captive portal profile.

=cut

sub getInternalSources {
    my ($self) = @_;
    return grep { $_->{'class'} eq 'internal' } $self->getSourcesAsObjects();
}

=item getExternalSources

Returns the external authentication sources objects for the current captive portal profile.

=cut

sub getExternalSources {
    my ($self) = @_;
    return grep { $_->{'class'} eq 'external' } $self->getSourcesAsObjects();
}

=item getExclusiveSources

Returns the exclusive authentication sources objects for the current captive portal profile.

=cut

sub getExclusiveSources {
    my ($self) = @_;
    return grep { $_->{'class'} eq 'exclusive' } $self->getSourcesAsObjects();
}

=item getSourceByType

Returns the first source object for the requested source type for the current captive portal profile.

=cut

sub getSourceByType {
    my ($self, $type) = @_;
    my $result;
    if ($type) {
        $type = uc($type);
        $result = first {uc($_->{'type'}) eq $type} $self->getSourcesAsObjects;
    }

    return $result;
}

=item guestRegistrationOnly

Returns true if the profile only uses "sign-in" authentication sources (SMS, email or sponsor).

=cut

sub guestRegistrationOnly {
    my ($self) = @_;
    my @sources = $self->getSourcesAsObjects();
    return $FALSE if (@sources == 0);

    my %registration_types =
      (
       pf::Authentication::Source::EmailSource->meta->get_attribute('type')->default => undef,
       pf::Authentication::Source::SMSSource->meta->get_attribute('type')->default => undef,
       pf::Authentication::Source::SponsorEmailSource->meta->get_attribute('type')->default => undef,
      );

    my $result = all { exists $registration_types{$_->{'type'}} } @sources;

    return $result;
}

=item guestModeAllowed

Verify if the guest mode is allowed for the profile

=cut

sub guestModeAllowed {
    my ($self, $mode) = @_;
    return any { $mode eq $_} @{$self->getGuestModes} ;
}

=item nbregpages

The number of registration pages to be shown before signup or registration

=cut

sub nbregpages {
    my ($self) = @_;
    return $self->{'_nbregpages'};
}

=item reuseDot1xCredentials

Reuse dot1x credentials when authenticating

=cut

sub reuseDot1xCredentials {
    my ($self) = @_;
    return $self->{'_reuse_dot1x_credentials'};
}

=item noPasswordNeeded

Check if the profile needs no password

=cut

sub noPasswordNeeded {
    my ($self) = @_;
    return isenabled($self->reuseDot1xCredentials) || any { $_ eq 'null' } @{ $self->getGuestModes };
}

=item noUsernameNeeded

Check if the profile needs no username

=cut

sub noUsernameNeeded {
    my ($self) = @_;
    return isenabled($self->reuseDot1xCredentials) || any { $_->type eq 'Null' && isdisabled( $_->email_required ) } $self->getSourcesAsObjects;
}

=item provisionerObjects

The provisionerObjects

=cut

sub provisionerObjects {
    my ($self) = @_;
    return grep { defined $_ } map { pf::factory::provisioner->new($_) } @{ $self->getProvisioners || [] };
}

sub findProvisioner {
    my ($self, $mac, $node_attributes) = @_;
    my $logger = get_logger();
    $node_attributes ||= node_attributes($mac);
    my ($fingerprint) =
      dhcp_fingerprint_view( $node_attributes->{'dhcp_fingerprint'} );
    unless($fingerprint){
        $logger->warn("Can't find provisioner for $mac since we don't have it's fingerprint");
        return;
    }
    my $os = $fingerprint->{'os'};
    unless(defined $os){
        $logger->warn("Can't find provisioner for $mac since we don't have it's OS");
        return;
    }
    return first { $_->match($os,$node_attributes) } $self->provisionerObjects;
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
