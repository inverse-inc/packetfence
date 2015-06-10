package captiveportal::PacketFence::Controller::Billing;
use Moose;
use namespace::autoclean;
use pf::config;
use URI::Escape::XS qw(uri_escape uri_unescape);
use pf::billing::constants;
use pf::billing::custom;
use pf::config;
use pf::iplog;
use pf::node;
use pf::trigger;
use pf::person qw(person_modify);
use pf::Portal::Session;
use pf::util;
use pf::config::util;
use pf::violation;
use pf::web;
use pf::web::billing 1.00;
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
    unless( $c->profile->isBillingEnabled ) {
        $c->response->redirect("/captive-portal?destination_url=".uri_escape($c->portalSession->profile->getRedirectURL));
        $c->detach;
    }
    $c->forward(CaptivePortal => 'validateMac');
}

=head2 source

The chained billing source

=cut

sub source : Chained('/') : PathPart('billing') : CaptureArgs(1) {
    my ($self, $c, $source_id) = @_;
    my $profile = $c->profile;
    my $billing = first {$_->id eq $source_id} $profile->getBillingSources;
    unless ($billing) {
        $self->showError($c, "Invalid billing source for profile");
    }
    $c->stash->{billing} = $billing;
}

=head2 verify

=cut

sub verify : Chained('source') : Args(0) {
    my ($self, $c) = @_;
    my $request = $c->request;
    my $billing = $c->stash->{billing};
    my $data;
    eval {
        $data = $billing->verify($c->session, $request->parameters, $request->path);
    };
    if ($@) {
        $c->log->error($@);
    }
    else {
        $c->stash($data);
    }
}

=head2 confirm

=cut

sub confirm : Local : Args(0) {
    my ($self, $c) = @_;
    $c->forward('validate');
    my $billing = $c->stash->{billing};
    my $data;
    eval {
        $data =
          $billing->prepare_payment($c->session, $c->stash->{tier}, $c->request->parameters, $c->request->path);
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

=cut

sub validate : Private {
    my ($self, $c) = @_;
    my $request = $c->request;
    #Check if the billing source provided is correct
    $self->source($c, $request->param("source"));
    my $selected_tier = $request->param('tier');
    my $first_name = $request->param('firstname');
    my $last_name = $request->param('lastname');
    my $email = $request->param('email');
    unless ($selected_tier) {
        $c->log->error("No Tier selected");
        $c->stash({
            template => 'billing/index.html',
            txt_validation_error => 'No Tier selected',
        });
        $c->detach('index');
    }
    my $tier = $c->profile->findTier($selected_tier);
    unless ($tier) {
        $c->log->error("Selected Tier is invalid");
        $c->stash({
            template => 'billing/index.html',
            txt_validation_error => 'Selected Tier is invalid',
        });
        $c->detach('index');
    }
    my $valid_name = ( pf::web::util::is_name_valid($first_name)
            && pf::web::util::is_name_valid($last_name) );
    my $valid_email = pf::web::util::is_email_valid($email);
    $c->session(
        "firstname" => $first_name,
        "lastname"  => $last_name,
        "email"     => $email,
        "login"     => $email,
        "tier"      => $tier,
    );
    $c->stash(tier => $tier,);
}

=head2 cancel

=cut

sub cancel : Chained('source') : Args(0) {
    my ($self, $c) = @_;
    my $request = $c->request;
    my $billing = $c->stash->{billing};
    my $data;
    eval {
        $data = $billing->cancel($c->session, $request->parameters, $request->path);
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

=cut

sub index : Path : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{profile} = $c->profile;
}

sub processTransaction : Private {
    my ($self, $c) = @_;
    my $billingObj = new pf::billing::custom();
    my $request = $c->request;
    my $logger = $c->log;
    my $portalSession = $c->portalSession;
    my $profile       = $c->profile;
    my $mac = $portalSession->clientMac;

    # Transactions informations
    my $tier                  = $request->param('tier');
    my %tiers_infos           = $billingObj->getAvailableTiers();
    my $transaction_infos_ref = {
        ip             => $portalSession->clientIp(),
        mac            => $mac,
        firstname      => $request->param('firstname'),
        lastname       => $request->param('lastname'),
        email          => lc($request->param('email')),
        ccnumber       => $request->param('ccnumber'),
        ccexpiration   => $request->param('ccexpiration'),
        ccverification => $request->param('ccverification'),
        item           => $tier,
        price          => $tiers_infos{$tier}{'price'},
        description    => $tiers_infos{$tier}{'description'},
    };

    # Process the transaction
    my $paymentStatus =
      $billingObj->processTransaction($transaction_infos_ref);
    my $pid = $c->session->{'login'};

    if ($paymentStatus eq $BILLING::SUCCESS) {

        # Adding person (using modify in case person already exists)
        person_modify(
            $pid,
            (   'firstname' => $request->param('firstname'),
                'lastname'  => $request->param('lastname'),
                'email'     => lc($request->param('email')),
                'notes'     => 'billing engine activation - ' . $tier,
                'portal'    => $profile->getName,
                'source'    => 'billing',
            )
        );

        # Grab additional infos about the node
        my %info;
        my $timeout = normalize_time($tiers_infos{$tier}{'timeout'});
        $info{'pid'}      = $pid;
        $info{'category'} = $tiers_infos{$tier}{'category'};
        $info{'unregdate'} =
          POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $timeout));

        if ($tiers_infos{$tier}{'usage_duration'}) {
            $info{'time_balance'} =
              normalize_time($tiers_infos{$tier}{'usage_duration'});

            # Check if node has some access time left; if so, add it to the new duration
            my $node = node_view($mac);
            if ($node && $node->{'time_balance'} > 0) {
                if ($node->{'last_start_timestamp'} > 0) {

                    # Node is active; compute the actual access time left
                    my $expiration = $node->{'last_start_timestamp'}
                      + $node->{'time_balance'};
                    my $now = time;
                    if ($expiration > $now) {
                        $info{'time_balance'} += ($expiration - $now);
                    }
                } else {

                    # Node is inactive; add the remaining access time to the purchased access time
                    $info{'time_balance'} += $node->{'time_balance'};
                }
            }
            $logger->info(
                "Usage duration for $mac is now " . $info{'time_balance'});
        }

        # Close violations that use the 'Accounting::BandwidthExpired' trigger
        my @tid = trigger_view_tid($ACCOUNTING_POLICY_TIME);
        foreach my $violation (@tid) {

            # Close any existing violation
            violation_force_close($mac, $violation->{'vid'});
        }

        # Register the node
        $c->forward( 'CaptivePortal' => 'webNodeRegister', [$info{pid}, %info] );

        my $confirmationInfo = {
            tier => $request->param('tier'),
            firstname => $request->param('firstname'),
            lastname => $request->param('lastname'),
            email => $request->param('email'),
        };
        # Send confirmation email
        my %data =
          $billingObj->prepareConfirmationInfo($transaction_infos_ref, $confirmationInfo);
        pf::util::send_email('billing_confirmation', $data{'email'},
            $data{'subject'}, \%data);

        # Generate the release page
        # XXX Should be part of the portal profile

        $c->forward( 'CaptivePortal' => 'endPortalSession' );
    } else { # There was an error with the payment processing
        $logger->warn(
            "There was an error with the payment processing for email $transaction_infos_ref->{email} "
              . "(MAC: $transaction_infos_ref->{mac})");
        $c->stash->{'txt_validation_error'} = $BILLING::ERRORS{$BILLING::ERROR_PAYMENT_GATEWAY_FAILURE};
        $c->detach('showBilling');
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

Copyright (C) 2005-2015 Inverse inc.

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
