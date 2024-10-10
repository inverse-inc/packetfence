package pf::provisioner;

=head1 NAME

pf::provisioner add documentation

=cut

=head1 DESCRIPTION

pf::provisioner

=cut

use strict;
use warnings;
use Moo;
use pf::constants;
use pf::config;
use pf::fingerbank;
use Readonly;
use pf::log;
use pf::factory::pki_provider;
use List::MoreUtils qw(any);
use pf::CHI;
use fingerbank::Model::Device;
use pf::util qw(isenabled);
use Time::HiRes qw(time);
use pfconfig::cached_hash;
use pf::access_filter::provisioner;

our %ProvisioningScopes;
tie %ProvisioningScopes, 'pfconfig::cached_hash', 'FilterEngine::ProvisionerScopes';

=head1 Constants

head2 COMMUNICATION_FAILED

=cut

Readonly::Scalar our $COMMUNICATION_FAILED => -1;

=head1 Atrributes

=head2 id

The id of the provisioner

=cut

has id => (is => 'rw');

=head2 type

The type of the provisioner

=cut

has type => (is => 'rw');

=head2 description

The description of the provisioner

=cut

has description => (is => 'rw');

=head2 category

The category of the provisioner

=cut

has category => (is => 'rw', default => sub { [] });

=head2 skipDeAuth

If we can skip deauth for a node after being provisioned

=cut

has skipDeAuth => (is => 'rw', default => sub { 0 });

=head2 template

The template to use for provisioning

=cut

has template => (is => 'rw', lazy => 1, builder => 1 );

=head2 oses

The oses to match against

=cut

has oses => (is => 'rw', default => sub { [] } );

=head2 rules

The rules to match against

=cut

has rules => (is => 'rw', default => sub { [] } );

=head2 enforce

If the provisioner has to be enforced on each connection

=cut

has enforce => (is => 'rw', default => sub { 'enabled' });

=head2 autoregister

If a role should be applied to the devices authorized in the provisioner

=cut

has autoregister => (is => 'rw', default => sub { 'disabled' });

=head2 apply_role

If a role should be applied to the devices authorized in the provisioner

=cut

has apply_role => (is => 'rw', default => sub { 'disabled' });

=head2 role_to_apply

Role to apply when apply_role is enabled

=cut

has role_to_apply => (is => 'rw', default => sub { 'default' });

=head2 non_compliance_security_event

Which security_event should be raised when a device is not compliant

=cut

has non_compliance_security_event => (is => 'rw' );

=head2 pki_provider

The id of the pki provider

=cut

has pki_provider => (is => 'rw');

has access_filter => (is => 'rw', default => sub { pf::access_filter::provisioner->new() });

=head1 METHODS

=head2 _build_template

Creates a template from the name of the class

=cut

sub _build_template {
    my ($self) = @_;
    my $type = ref($self) || $self;
    $type =~ s/^pf:://;
    $type =~ s/::/\//g;
    return "${type}.html";
}

=head2 supportsPolling

Whether or not the provisioner supports polling info for compliance check

=cut

sub supportsPolling {return 0}

=head2 supportsPolling

Whether or not the provisioner supports polling info for compliance check

=cut

sub pollChangedDevices {
    my ($self, $timeframe) = @_;
    my $logger = get_logger();
    $logger->error("Called pollChangedDevices on a provisioner that doesn't support it");
    return [];
}

=head2 matchCategory

=cut

sub matchCategory {
    my ($self, $node_attributes) = @_;
    my $category = $self->category || [];
    my $node_cat = $node_attributes->{'category'};

    get_logger->trace( sub { "Tring to match the role '$node_cat' against " . join(",", @$category) });
    # validating that the node is under the proper category for provisioner
    return @$category == 0 || any { $_ eq $node_cat } @$category;
}

=head2 matchOS

=cut

sub matchOS {
    my ($self, $node_attributes) = @_;
    my @oses = @{$self->oses || []};

    #if no oses are defined then it will match all the oses
    return $TRUE if @oses == 0;

    my $device_name = $node_attributes->{device_type};
    get_logger->debug( sub { "Trying see if device $device_name is one of: " . join(",", @oses) });

    for my $os (@oses) {
        return $TRUE if fingerbank::Model::Device->is_a($device_name, $os);
    }

    return $FALSE;
}

sub _getRulesForScope {
    my ($self, $scope) = @_;
    return if !exists $ProvisioningScopes{$scope};
    my @rulesIds = @{$self->rules};
    return if @rulesIds == 0;
    my $scopeLookup = $ProvisioningScopes{$scope};
    my @rules;
    for my $id (@rulesIds) {
        next if !exists $scopeLookup->{$id};
        my $rule = $scopeLookup->{$id};
        push @rules, $rule if defined $rule;
    }

    return @rules;
}

sub handleAnswer {
    my ($self, $answer, $data) = @_;
    $self->access_filter->dispatchActions($answer, $data);
    return;
}

sub matchRules {
    my ($self, $node_attributes) = @_;
    #if no rules are defined then it is true
    my %data = (node_info => $node_attributes);
    my ($answer, $empty) = $self->getAnswerForScope('lookup', \%data);
    return defined $answer || $empty  ? $TRUE : $FALSE;
}

sub handleAuthorizeEnforce {
    my ($self, $mac, $data, $return_empty) = @_;
    $return_empty //= $TRUE;
    my ($answer, $empty) = $self->getAnswerForScope('authorize_enforce', $data);
    return $return_empty if $empty;
    return $FALSE if !defined $answer;

    $self->handleAnswer($answer, $data);
    return $TRUE;
}

=head2 match

=cut

sub match {
    my ($self, $os, $node_attributes) = @_;
    $node_attributes->{device_type} = defined($os) ? $os : $node_attributes->{device_name};
    return $self->matchCategory($node_attributes) && $self->matchOS($node_attributes) && $self->matchRules($node_attributes);
}

=head2 getPkiProvider

=cut

sub getPkiProvider {
    my ($self) = @_;
    my $pki_provider_id = $self->pki_provider;
    return undef unless $pki_provider_id;
    return pf::factory::pki_provider->new($pki_provider_id);
}

=head2 cache

Get the provisioning cache

=cut

sub cache {
    my ($self) = @_;
    return pf::CHI->new(namespace => 'provisioning');
}

=head2 authorize_enforce

Enforce the provisioning if necessary

=cut

sub authorize_enforce {
    my ($self, $mac) = @_;
    if(isenabled($self->enforce)) {
        return $self->authorize($mac);
    }
    else {
        return $TRUE;
    }
}

=head2 authorize_apply_role

Check if a role should be applied to the device based on the provisioner

=cut

sub authorize_apply_role {
    my ($self, $mac) = @_;
    my $type = $self->type;
    my $started = time;
    my $result = $self->cache->compute_with_undef("$type-authorize_apply_role($mac)",
        sub {
            if(isenabled($self->apply_role)) {
                my $auth = $self->authorize($mac);
                if($auth eq $pf::provisioner::COMMUNICATION_FAILED) {
                    get_logger->error("Will not be able to apply the role to this device since the communication with the provisioner has failed");
                    return undef;
                }
                elsif($auth) {
                    my $role = $self->role_to_apply;
                    return $role;
                }
            }
            return undef;
        }
    );

    my $elapsed_ms = ((time - $started) * 1000);
    my $tolerable_latency = 750;
    if($elapsed_ms > $tolerable_latency) {
        get_logger->warn("Computing the provisioning authorization took more than $tolerable_latency milliseconds ($elapsed_ms ms). This will have a negative impact on the RADIUS response time and can cause a RADIUS timeout.");
    }
    else {
        get_logger->debug("Computing the provisioning authorization took $elapsed_ms milliseconds");
    }

    return $result;
}

sub getAnswerForScope {
    my ($self, $scope, $data) = @_;
    return $self->access_filter->filterRules($scope, $data, $self->rules);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
