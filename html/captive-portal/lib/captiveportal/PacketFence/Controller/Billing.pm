package captiveportal::PacketFence::Controller::Billing;
use Moose;
use namespace::autoclean;
use pf::config;
use URI::Escape::XS qw(uri_escape uri_unescape);
use pf::config;
use pf::iplog;
use pf::node;
use pf::Portal::Session;
use pf::util;
use pf::config::util;
use pf::config::violation;
use pf::violation;
use pf::person;
use pf::web;
use List::Util qw(first);

BEGIN {extends 'captiveportal::Base::Controller';}

=head1 NAME

captiveportal::PacketFence::Controller::Billing - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 begin

=cut

sub begin : Private {
    my ($self, $c) = @_;
    unless( $c->profile->getBillingSources() ) {
        $self->showError("Couldn't find any billing source");
    }
}

=head2 source

The billing source to use

=cut

sub source : Chained('/') : PathPart('billing') : CaptureArgs(1) {
    my ($self, $c, $source_id) = @_;
    my $profile = $c->profile;
    my $billing;
    $billing = first {$_->id eq $source_id} $profile->getBillingSources;
    unless ($billing) {
        $c->response->redirect("/captive-portal?destination_url=".uri_escape($c->portalSession->profile->getRedirectURL) . "&txt_validation_error=Your session has expired cannot access billing try again");
        $c->detach;
    }
    $c->session->{source_id} = $billing->id;
    $c->stash->{billing} = $billing;
}

=head2 verify

Does the verification process with the billing provider

=cut

sub verify : Chained('source') : Args(0) {
    my ($self, $c) = @_;
    my $request = $c->request;
    my $billing = $c->stash->{billing};
    my $data;
    eval {
        $c->session(billed_mac => $c->portalSession->clientMac);
        $data = $billing->verify($c->session, $request->parameters, $request->uri);
    };
    if ($@) {
        $c->log->error($@);
        $self->showError($c, "Unable to process payment");
    }
    else {
        $c->forward('processTransaction');
    }
}

=head2 confirm

Shows a confirm page with a summary of the transaction before the user completes the process with the provider

=cut

sub confirm : Local : Args(0) {
    my ($self, $c) = @_;
    $c->log->debug("Entering billing confirmation");
    $c->forward('validate');

    my $billing = $c->stash->{billing};

    my $pid  = $c->session->{'email'};
    if($pid){
        my @fields = $c->profile->getFieldsForSources($billing);
        my %person_fields;
        foreach my $field (@fields){
            $person_fields{$field} = $c->session->{$field};
        }
        person_modify($pid, %person_fields);
    }

    my $data = eval {
          $billing->prepare_payment($c->session, $c->stash->{tier}, $c->request->parameters, $c->request->uri)
    };
    if ($@) {
        $c->log->error($@);
        $c->stash(template => 'billing/index.html');
        $c->detach('index');
    }
    $c->stash($data);
    $c->stash(template => "billing/confirm_" . $billing->type . ".html");
}

=head2 validate

Validate the tier selection and mandatory fields if any

=cut

sub validate : Private {
    my ($self, $c) = @_;
    my $request = $c->request;

    my $source_param = first { /^billing_source_/ } $request->param_names;
    if($source_param =~ /^billing_source_(.*)/) {
        $self->source($c, $1);
    } else {
        $self->showError($c, "Invalid billing source for profile");
    }

    #Check if the billing source provided is correct
    my $selected_tier = $request->param('tier');
    unless ($selected_tier) {
        $c->log->error("No Tier selected");
        $c->stash({
            template => 'billing/index.html',
            txt_validation_error => 'No Tier selected',
        });
        $c->detach('index');
    }
    my $tier = $c->profile->getBillingTier($selected_tier);
    unless ($tier) {
        $c->log->error("Selected Tier is invalid");
        $c->stash({
            template => 'billing/index.html',
            txt_validation_error => 'Selected Tier is invalid',
        });
        $c->detach('index');
    }

    $c->forward(Authenticate => "validateMandatoryFields", [detach => 0]);
    if($c->stash->{'txt_validation_error'}){
        $c->log->error("Invalid mandatory fields");
        $c->stash({
            template => 'billing/index.html',
        });
        $c->detach('index');
    }

    $c->session(tier => $tier);
    $c->stash(tier => $tier);
}

=head2 cancel

Cancel transaction with billing provider

=cut

sub cancel : Chained('source') : Args(0) {
    my ($self, $c) = @_;
    my $request = $c->request;
    my $billing = $c->stash->{billing};
    my $data;
    eval {
        $data = $billing->cancel($c->session, $request->parameters, $request->uri);
    };
    if ($@) {
        $c->log->error($@);
    }
    else {
        $c->stash($data);
    }
    $c->stash({
        template => 'billing/index.html',
        txt_validation_error => 'Order was canceled',
    });
    $c->detach('index');
}

=head2 index

Index page for the billing to require mandatory fields if any, select a tier and a billing source

=cut

sub index : Path : Args(0) {
    my ($self, $c) = @_;
    my @billing_sources = $c->profile->getBillingSources;

    my @mandatory_fields = $c->profile->getFieldsForSources(@billing_sources);
    $c->stash( mandatory_fields => \@mandatory_fields );

    $c->stash(
        billing_sources => \@billing_sources,
        profile => $c->profile,
        template => 'billing/index.html',
    );
}

=head2 processTransaction

Manipulations to do after a transaction is completed

Save any informations about the user

Apply the proper access and release the node on the network

=cut

sub processTransaction : Private {
    my ($self, $c) = @_;
    my $portalSession = $c->portalSession;
    my $profile       = $c->profile;
    my $session       = $c->session;
    my $request       = $c->request;
    my $logger        = $c->log;
    my $mac           = $portalSession->clientMac;

    # Transactions informations
    my $tier = $session->{'tier'};
    my $pid  = $session->{'email'} || $default_pid;
    my $billing = $c->stash->{billing};

    my $application = $c->stash->{application};

    my $info = $application->root_module->new_node_info();
    my $access_duration = normalize_time($tier->{'access_duration'});
    # we set it in the root_module in case we can't find the billing module due to a session error.
    $application->root_module->username($pid);

    $info->{'category'} = $tier->{'role'};
    $info->{'unregdate'} =
      POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $access_duration));

    if (isenabled($tier->{'use_time_balance'})) {
        $info->{'time_balance'} =
          normalize_time($tier->{'access_duration'});

        # Check if node has some access time left; if so, add it to the new duration
        my $node = node_view($mac);
        if ($node && $node->{'time_balance'} > 0) {
            if ($node->{'last_start_timestamp'} > 0) {
                # Node is active; compute the actual access time left
                my $expiration = $node->{'last_start_timestamp'} + $node->{'time_balance'};
                my $now        = time;
                if ($expiration > $now) {
                    $info->{'time_balance'} += ($expiration - $now);
                }
            }
            else {
                # Node is inactive; add the remaining access time to the purchased access time
                $info->{'time_balance'} += $node->{'time_balance'};
            }
        }
        $logger->info("Usage duration for $mac is now " . $info->{'time_balance'});
    }

    # Close violations that use the 'Accounting::BandwidthExpired' trigger
    foreach my $vid (@BANDWIDTH_EXPIRED_VIOLATIONS){
        # Close any existing violation
        violation_force_close($mac, $vid);
    }

    my $module = $captiveportal::DynamicRouting::Factory::INSTANTIATED_MODULES{$application->{billing_module_id}};
    if($module) {
        $module->done();
    }
    else {
        node_modify($mac, %{$application->root_module->new_node_info});
        $self->showError("Could not find billing module in your session. Your level of access has been recorded. Please contact your local support staff");
    }
}



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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
