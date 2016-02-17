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
use List::MoreUtils qw(all none any uniq);
use pf::constants qw($TRUE $FALSE);
use pf::constants::config qw($SELFREG_MODE_NULL $SELFREG_MODE_KICKBOX);
use pf::util;
use pf::config::util;
use pf::log;
use pf::node;
use pf::factory::provisioner;
use pf::ConfigStore::Scan;
use pf::StatsD::Timer;
use pf::config;

=head1 METHODS

=over

=item new

No one should call ->new by himself. L<pf::Portal::ProfileFactory> should
be used instead.

=cut

sub new {
    my $timer = pf::StatsD::Timer->new;
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

=item getChainedGuestModes

Returns the available enabled modes for guest self-registration for chained sources for the current captive portal profile.

=cut

sub getChainedGuestModes {
    my ($self) = @_;
    return $self->{'_chained_guest_modes'};
}

*chained_guest_modes = \&getChainedGuestModes;

=item getTemplatePath

Returns the path for custom templates for the current captive portal profile.

Relative to html/captive-portal/templates/

=cut

sub getTemplatePath {
    my ($self) = @_;
    return $self->{'_template_path'};
}

*template_path = \&getTemplatePath;

=item getBillingTiers

Get the billing tiers for this portal profile

=cut

sub getBillingTiers {
    my ($self) = @_;
    my @tier_ids = split(/\s*,\s*/,$self->{_billing_tiers});
    if(@tier_ids == 0){
        @tier_ids = keys %ConfigBillingTiers;
    }
    my @tiers;
    while(my ($tier_id, $tier) = each %ConfigBillingTiers){
        if(any { $_ eq $tier_id } @tier_ids){
            $tier->{id} = $tier_id;
            push @tiers, $tier;
        }
    }
    return \@tiers;
}

*billing_tiers = \&getBillingTiers;

=item getBillingTier

Get the configuration of a specific billing tier

=cut

sub getBillingTier {
    my ($self, $id) = @_;
    return $ConfigBillingTiers{$id};
}

=item getBillingSources

Return the billing authentication sources objects for the profile

=cut

sub getBillingSources {
    my ($self) = @_;
    return $self->getSourcesByClass( 'billing' );
}

=item hasBilling

Whether or not the profile has billing enabled

=cut

sub hasBilling {
    my ($self) = @_;
    return (scalar($self->getBillingSources()) > 0);
}

=item getSAMLSources

Get the SAML sources configured in this portal profile

=cut

sub getSAMLSources {
    my ($self) = @_;
    return map { ($_->type eq "SAML") ? $_ : () } $self->getSourcesAsObjects();
}

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


=item getCustomFields

Returns the custom fields configured on the portal profile

=cut

sub getCustomFields {
    my ( $self ) = @_;
    return $self->{'_mandatory_fields'};
}

*customFields = \&getCustomFields;

=item getCustomFieldsSources

Returns which authentication sources are configured to use custom fields.

=cut

sub getCustomFieldsSources {
    my ( $self ) = @_;
    return $self->{'_custom_fields_authentication_sources'};
}

*customFieldsSources = \&getCustomFieldsSources;

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
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.1});
    my ($self) = @_;
    my @sources = $self->getSourcesByClass( 'internal' );
    return @sources;
}

=item getExternalSources

Returns the external authentication sources objects for the current captive portal profile.

=cut

sub getExternalSources {
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.1});
    my ($self) = @_;
    my @sources = $self->getSourcesByClass( 'external' );
    return @sources;
}

=item getExclusiveSources

Returns the exclusive authentication sources objects for the current captive portal profile.

=cut

sub getExclusiveSources {
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.1});
    my ($self) = @_;
    my @sources = $self->getSourcesByClass( 'exclusive' );
    return @sources;
}

=item getSourcesByClass

Returns the sources for that match the class

=cut

sub getSourcesByClass {
    my ($self, $class) = @_;
    return unless defined $class;
    return grep { $_->class eq $class } $self->getSourcesAsObjects();
}

=item hasChained

If the profile has a chained auth source

=cut

sub hasChained {
    my ($self) = @_;
    return defined ($self->getSourceByType('chained')) ;
}

=item hasSource

If the profile has a specific source

=cut

sub hasSource {
    my ($self, $source_id) = @_;
    return any { $_->id eq $source_id } $self->getSourcesAsObjects();
}

=item getSourceByType

Returns the first source object for the requested source type for the current captive portal profile.

=cut

sub getSourceByType {
    my ($self, $type) = @_;
    return unless $type;
    $type = uc($type);
    return first {uc($_->{'type'}) eq $type} $self->getSourcesAsObjects;
}

=item getSourcesByType

Returns ALL the sources object for the requested source type for the current captive portal profile

=cut

sub getSourcesByType {
    my ($self, $type) = @_;
    return unless $type;
    $type = uc($type);
    return grep {uc($_->{'type'}) eq $type} $self->getSourcesAsObjects;
}

sub getSourcesByObjectClass {
    my ($self, $class) = @_;
    return unless($class);
    return grep {$_->isa($class)} $self->getSourcesAsObjects();
}

=item getSourceByTypeForChained

Returns the first source object for the requested source type for chained sources in the current captive portal profile.

=cut

sub getSourceByTypeForChained {
    my ($self, $type) = @_;
    return unless $type;
    $type = uc($type);
    return first {uc($_->{'type'}) eq $type} map { $_->getChainedAuthenticationSourceObject } grep { $_->type eq 'Chained' }  $self->getSourcesAsObjects;
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
       pf::Authentication::Source::NullSource->meta->get_attribute('type')->default => undef,
      );

    my $result = all { exists $registration_types{$_->{'type'}} } @sources;

    return $result;
}

sub billingRegistrationOnly {
    my ($self) = @_;
    my @sources = $self->getSourcesAsObjects();
    return $FALSE if(@sources == 0);

    return all { $_->class eq 'billing' } @sources;
}

=item guestModeAllowed

Verify if the guest mode is allowed for the profile

=cut

sub guestModeAllowed {
    my ($self, $mode) = @_;
    return any { $mode eq $_} @{$self->getGuestModes}, @{$self->getChainedGuestModes} ;
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
    return isenabled($self->reuseDot1xCredentials) || $self->getInternalSources == 0;
}

=item noUsernameNeeded

Check if the profile needs no username

=cut

sub noUsernameNeeded {
    my ($self) = @_;
    return isenabled($self->reuseDot1xCredentials) || $self->getInternalSources == 0;
}

=item provisionerObjects

The provisionerObjects

=cut

sub provisionerObjects {
    my ($self) = @_;
    return grep { defined $_ } map { pf::factory::provisioner->new($_) } @{ $self->getProvisioners || [] };
}

sub findProvisioner {
    my $timer = pf::StatsD::Timer->new();
    my ($self, $mac, $node_attributes) = @_;
    my $logger = get_logger();
    my @provisioners = $self->provisionerObjects;
    unless(@provisioners){
        $logger->trace("No provisioners configured for portal profile");
        return;
    }

    $node_attributes ||= node_attributes($mac);
    my $os = $node_attributes->{'device_type'};
    unless(defined $os){
        $logger->warn("Can't find provisioner for $mac since we don't have it's OS");
        return;
    }

    return first { $_->match($os,$node_attributes) } @provisioners;
}

=item dot1xRecomputeRoleFromPortal

Reuse dot1x credentials when authenticating

=cut

sub dot1xRecomputeRoleFromPortal {
    my ($self) = @_;
    return $self->{'_dot1x_recompute_role_from_portal'};
}

=item getScans

Returns the Scans IDs for the profile

=cut

sub getScans {
    my ($self) = @_;
    return $self->{'_scans'};
}

=item scanObjects

The scanObjects

=cut

sub scanObjects {
    my ($self) = @_;
    return grep { defined $_ } map { pf::factory::scan->new($_) } @{ $self->getScans || [] };
}

=item findScan

return the first scan that match the device

=cut

sub findScan {
    my $timer = pf::StatsD::Timer->new();
    my ($self, $mac, $node_attributes) = @_;
    my $scanners = $self->getScans;
    return undef unless defined $scanners;
    my $logger = get_logger();
    foreach my $scan (split(',', $scanners)) {
        my $scan_config = $pf::config::ConfigScan{$scan};
        my @categories  = split(',', $scan_config->{'categories'});
        my $oses        = $scan_config->{'oses'};

        # if there are no oses and no categories defined for the scan then select it
        if (!scalar(@$oses) && !scalar(@categories)) {
            return $scan_config;
        }
        $node_attributes ||= node_attributes($mac);

        # if there are an os and a category defined
        if (scalar(@$oses) && scalar(@categories)) {
            my $device_type = $node_attributes->{'device_type'} || '';
            my $fingerprint = pf::fingerbank::is_a($device_type);
            if ((grep {$fingerprint =~ $_} @$oses) && (grep {$_ eq $node_attributes->{'category'}} @categories)) {
                return $scan_config;
            }
            # Check next scan config
            next;
        }

        # if there is only an os
        if (scalar(@$oses)) {
            my $device_type = $node_attributes->{'device_type'} || '';
            my $fingerprint = pf::fingerbank::is_a($device_type);
            if (grep {$fingerprint =~ $_} @$oses) {
                return $scan_config;
            }
            # Check next scan config
            next;
        }

        # if there is only a category
        if (grep {$_ eq $node_attributes->{'category'}} @categories) {
            return $scan_config;
        }
    }

    return undef;
}

=item getFieldsForSources

Get the combined mandatory field from the profile and the sources provided

=cut

sub getFieldsForSources {
    my ($self, @sources) = @_;
    my @fields;
    my %custom_fields_authentication_sources = map { $_ => undef } @{$self->getCustomFieldsSources};
    if( any { exists $custom_fields_authentication_sources{$_->id} } @sources ) {
        @fields = @{$self->getCustomFields};
    }
    my @mandatoryFields = map {$_->mandatoryFields()} @sources;

    # Combine the profile and the source mandatory fields
    push @fields, @mandatoryFields;
    # Make sure mandatory fields are unique
    return uniq @fields;
}

sub getUserSources {
    my ($self, $username, $realm) = @_;
    return get_user_sources([ $self->getInternalSources, $self->getExclusiveSources ], $username, $realm);
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
