package pf::Connection::Profile;

=head1 NAME

pf::Connection::Profile

=cut

=head1 DESCRIPTION

pf::Connection::Profile wraps captive portal configuration in a way that we can
provide several differently configured (behavior and template) captive
portal from the same server.

=cut

use strict;
use warnings;

use POSIX;
use List::Util qw(first);
use List::MoreUtils qw(all none any uniq);
use pf::constants qw($TRUE $FALSE);
use pf::constants::config qw($SELFREG_MODE_NULL $SELFREG_MODE_KICKBOX);
use pf::constants::Connection::Profile qw($DEFAULT_ROOT_MODULE);
use pf::util;
use pf::config::util;
use pf::log;
use pf::node;
use pf::factory::provisioner;
use pf::factory::scan;
use pf::ConfigStore::Scan;
use pf::StatsD::Timer;
use pf::config qw(
    %ConfigBillingTiers
);

use pfconfig::memory_cached;

# a memory cache tied to the config::Profiles namepace
our $SOURCES_CACHE = pfconfig::memory_cached->new('config::Profiles', 'config::Authentication');

=head1 METHODS

=over

=item new

No one should call ->new by himself. L<pf::Connection::ProfileFactory> should
be used instead.

=cut

sub new {
    my $timer = pf::StatsD::Timer->new({level => 6});
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

Returns the name of the connection profile.

=cut

sub getName {
    my ($self) = @_;
    return $self->{'_name'};
}

*name = \&getName;

=item getLogo

Returns the logo for the current connection profile.

=cut

sub getLogo {
    my ($self) = @_;
    return $self->{'_logo'};
}

*logo = \&getLogo;

=item getGuestModes

Returns the available enabled modes for guest self-registration for the current connection profile.

=cut

sub getGuestModes {
    my ($self) = @_;
    return $self->{'_guest_modes'};
}

*guest_modes = \&getGuestModes;

=item getTemplatePath

Get the path of a template from the available template paths

=cut

sub getTemplatePath {
    my ($self, $name) = @_;
    foreach my $path (@{$self->{'_template_paths'}}){
        if(-f "$path/$name"){
            return "$path/$name";
        }
    }
    return;
}

=item findFirstTemplate

Find the first template in the list

=cut

sub findFirstTemplate {
    my ($self, $files) = @_;
    my $template_paths = $self->{_template_paths};
    foreach my $file (@$files) {
        return $file if any {-f "$_/$file"} @$template_paths
    }
    return undef;
}

sub findViolationTemplate {
    my ($self, $template, $langs) = @_;
    my @new_langs;
    for my $lang (@$langs) {
        push @new_langs, $lang;
        if ($lang =~ /^(..)_(..)/) {
            push @new_langs, lc($1);
        }
    }
    my @subTemplates  = ((map {"violations/${template}.${_}.html"} @new_langs), "violations/$template.html");
    return $self->findFirstTemplate(\@subTemplates);
}

=item getBillingTiers

Get the billing tiers for this connection profile

=cut

sub getBillingTiers {
    my ($self) = @_;
    my $tier_ids = $self->{_billing_tiers};
    if(@$tier_ids == 0){
        $tier_ids = [sort(keys %ConfigBillingTiers)];
    }
    my @tiers;
    foreach my $tier_id (@$tier_ids) {
        my $tier = $ConfigBillingTiers{$tier_id};
        $tier->{id} = $tier_id;
        push @tiers, $tier;
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

Get the SAML sources configured in this connection profile

=cut

sub getSAMLSources {
    my ($self) = @_;
    return map { ($_->type eq "SAML") ? $_ : () } $self->getSourcesAsObjects();
}

=item getDescripton

Returns either enabled or disabled according to the billing engine state for the current connection profile.

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

Returns the authentication sources IDs for the current connection profile.

=cut

sub getSources {
    my ($self) = @_;
    return $self->{'_sources'};
}

*sources = \&getSources;

sub getProvisioners {
    my ($self) = @_;
    return $self->{'_provisioners'};
}

sub getDeviceRegistration {
    my ($self) = @_;
    return $self->{'_device_registration'};
}

=item getSourcesAsObjects

Returns the authentication sources objects for the current connection profile.

=cut

sub getSourcesAsObjects {
    my ($self) = @_;
    my $sources = $SOURCES_CACHE->compute_from_subcache($self->getName, sub {
        [ grep { defined $_ } map { pf::authentication::getAuthenticationSource($_) } @{$self->getSources()} ]
    } );
    return @$sources;
}

=item getInternalSources

Returns the internal authentication sources objects for the current connection profile.

=cut

sub getInternalSources {
    my $timer = pf::StatsD::Timer->new({level => 7});
    my ($self) = @_;
    my @sources = $self->getSourcesByClass( 'internal' );
    return @sources;
}

=item getExternalSources

Returns the external authentication sources objects for the current connection profile.

=cut

sub getExternalSources {
    my $timer = pf::StatsD::Timer->new({level => 7});
    my ($self) = @_;
    my @sources = $self->getSourcesByClass( 'external' );
    return @sources;
}

=item getExclusiveSources

Returns the exclusive authentication sources objects for the current connection profile.

=cut

sub getExclusiveSources {
    my $timer = pf::StatsD::Timer->new({level => 7});
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

=item hasSource

If the profile has a specific source

=cut

sub hasSource {
    my ($self, $source_id) = @_;
    return any { $_->id eq $source_id } $self->getSourcesAsObjects();
}

=item getSourceByType

Returns the first source object for the requested source type for the current connection profile.

=cut

sub getSourceByType {
    my ($self, $type) = @_;
    return unless $type;
    $type = uc($type);
    return first {uc($_->{'type'}) eq $type} $self->getSourcesAsObjects;
}

=item getSourcesByType

Returns ALL the sources object for the requested source type for the current connection profile

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
    return any { $mode eq $_} @{$self->getGuestModes};
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
    my $timer = pf::StatsD::Timer->new({level => 7});
    my ($self, $mac, $node_attributes) = @_;
    my $logger = get_logger();
    my @provisioners = $self->provisionerObjects;
    unless(@provisioners){
        $logger->trace("No provisioners configured for connection profile");
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

=item dot1xUnsetOnUnmatch

On autoreg if no authentication source return a role then unset the current node one

=cut

sub dot1xUnsetOnUnmatch {
    my ($self) = @_;
    return $self->{'_dot1x_unset_on_unmatch'};
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
    return grep { defined $_ } map { pf::factory::scan->new($_) } @{  $self->getScans // [] };
}

=item findScan

return the first scan that match the device

=cut

sub findScan {
    my $timer = pf::StatsD::Timer->new({level => 7});
    my ($self, $mac, $node_attributes) = @_;
    my $logger = get_logger();
    my @scanners = $self->scanObjects;
    unless(@scanners){
        $logger->trace("No scan engine configured for connection profile");
        return;
    }

    $node_attributes ||= node_attributes($mac);
    my $os = $node_attributes->{'device_type'};
    unless(defined $os){
        $logger->warn("Can't find scan engine for $mac since we don't have it's OS");
        return;
    }

    return first { $_->match($os,$node_attributes) } @scanners;
}

=item getFilteredAuthenticationSources

Return a list of authentication sources for the given connection profile filtered for a given username / realm

=cut

sub getFilteredAuthenticationSources {
    my ($self, $username, $realm) = @_;
    return @{filter_authentication_sources([ $self->getInternalSources, $self->getExclusiveSources ], $username, $realm) // []};
}

=item getRootModuleId

Get the root module ID for the connection profile

=cut

sub getRootModuleId {
    my ($self) = @_;
    return $self->{_root_module} || $DEFAULT_ROOT_MODULE;
}

=item getLocalizedTemplate 

Get a template based on the current locale

=cut

sub getLocalizedTemplate {
    my ($self, $base_template) = @_;
    my $locale = setlocale(POSIX::LC_MESSAGES);
    my @parts = split(/\./, $base_template);
    my $suffix = pop(@parts);
    my $prefix = join('.', @parts);
    if(defined($locale) && $locale =~ /([a-zA-Z]+)_?/) {
        my $short_locale = $1;
        my $localized_aup = "$prefix.$short_locale.$suffix";
        if(defined($self->getTemplatePath($localized_aup))) {
            return $localized_aup;
        }
    }
    return $base_template;
}

=item canAccessRegistrationWhenRegistered

Should the user be able to access the registration part of the portal even if he is registered

=cut

sub canAccessRegistrationWhenRegistered {
    my ($self) = @_;
    return isenabled($self->{_access_registration_when_registered});
}

=item dpskEnabled

Is DPSK is enable or not on this connection profile

=cut

sub dpskEnabled {
    my ($self) = @_;
    return isenabled($self->{'_dpsk'});
};

=item unregOnAcctStop

Deregister device on accounting stop

=cut

sub unregOnAcctStop {
    my ($self) = @_;
    return isenabled($self->{'_unreg_on_acct_stop'});
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
