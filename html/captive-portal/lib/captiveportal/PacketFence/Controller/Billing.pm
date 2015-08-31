package captiveportal::PacketFence::Controller::Billing;
use Moose;
use namespace::autoclean;
use pf::config;
use URI::Escape::XS qw(uri_escape uri_unescape);
use pf::billing::constants;
use pf::billing::custom;
use pf::billing;
use pf::config;
use pf::iplog;
use pf::node;
use pf::trigger;
use pf::person qw(person_modify);
use pf::Portal::Session;
use pf::util;
use pf::config::util;
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
    unless( $c->profile->isBillingEnabled() ) {
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
    my $billing;
    if($c->session->{chained_source}) {
        $billing = first {$_->id eq $source_id} $profile->getChainedBillingSources;
    }
    else {
        $billing = first {$_->id eq $source_id} $profile->getBillingSources;
    }
    unless ($billing) {
        $c->response->redirect("/captive-portal?destination_url=".uri_escape($c->portalSession->profile->getRedirectURL) . "&txt_validation_error=Your session has expired cannot access billing try again");
        $c->detach;
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
        $self->showError($c, "Unable to process payment");
    }
    else {
        $c->forward('processTransaction');
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
    my $source_param = first { /^billing_source_/ } $request->param_names;
    if($source_param =~ /^billing_source_(.*)/) {
        $self->source($c, $1);
    } else {
        $self->showError($c, "Invalid billing source for profile");
    }
    #Check if the billing source provided is correct
    my $selected_tier = $request->param('tier');
    my $first_name = $request->param('firstname');
    my $last_name = $request->param('lastname');
    my $email;
    my $person;
    if($c->session->{username}) {
        $person = person_view($c->session->{username});
        $email = $c->session->{username}
    }
    else {
        $email = $request->param('email');
    }
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
    my %temp = (
        "firstname" => $first_name,
        "lastname"  => $last_name,
        "email"     => $email,
        "username"  => $email,
        "tier"      => $tier,
    );
    $c->session(%temp);
    $c->stash(%temp);
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
    my @billing_sources = $c->profile->getBillingSources;
    unless(@billing_sources) {
        @billing_sources = $c->profile->getChainedBillingSources;
    }
    $c->stash(
        billing_sources => \@billing_sources,
        profile => $c->profile,
        template => 'billing/index.html',
    );
}

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
    my $pid  = $session->{'username'};
    my $billing = $c->stash->{billing};

    # Adding person (using modify in case person already exists)
    person_modify(
        $pid,
        (   'firstname' => $session->{'firstname'},
            'lastname'  => $session->{'lastname'},
            'email'     => lc($session->{'email'}),
            'notes'     => 'billing engine activation - ' . $tier->{id},
            'portal'    => $profile->getName,
            'source'    => $billing->id,
        )
    );

    # Grab additional infos about the node
    my %info;
    my $access_duration = normalize_time($tier->{'access_duration'});
    $info{'pid'}      = $pid;
    $info{'category'} = $tier->{'category'};
    $info{'unregdate'} =
      POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $access_duration));

    if ($tier->{'usage_duration'}) {
        $info{'time_balance'} =
          normalize_time($tier->{'usage_duration'});

        # Check if node has some access time left; if so, add it to the new duration
        my $node = node_view($mac);
        if ($node && $node->{'time_balance'} > 0) {
            if ($node->{'last_start_timestamp'} > 0) {

                # Node is active; compute the actual access time left
                my $expiration = $node->{'last_start_timestamp'} + $node->{'time_balance'};
                my $now        = time;
                if ($expiration > $now) {
                    $info{'time_balance'} += ($expiration - $now);
                }
            }
            else {

                # Node is inactive; add the remaining access time to the purchased access time
                $info{'time_balance'} += $node->{'time_balance'};
            }
        }
        $logger->info("Usage duration for $mac is now " . $info{'time_balance'});
    }

    # Close violations that use the 'Accounting::BandwidthExpired' trigger
    my @tid = trigger_view_tid($ACCOUNTING_POLICY_TIME);
    foreach my $violation (@tid) {

        # Close any existing violation
        violation_force_close($mac, $violation->{'vid'});
    }

    # Register the node
    $c->forward('CaptivePortal' => 'webNodeRegister', [$info{pid}, %info]);

    my %data = $self->prepareConfirmationInfo($c);
    # Send confirmation email
    pf::config::util::send_email('billing_confirmation', $data{'email'}, $data{'subject'}, \%data);

    # Generate the release page
    # XXX Should be part of the portal profile

    $c->forward('CaptivePortal' => 'endPortalSession');
}


=head2 prepareConfirmationInfo

=cut

sub prepareConfirmationInfo {
    my ( $self, $c) = @_;
    my $logger = $c->log;
    my $session = $c->session;
    my $tier = $session->{tier};

    my %info = ( pf::web::constants::to_hash() );

    $info{'firstname'} = $session->{firstname};
    $info{'lastname'} = $session->{lastname};
    $info{'email'} = $session->{email};
    $info{'tier_name'} = $tier->{'name'};
    $info{'tier_description'} = $tier->{'description'};
    $info{'tier_price'} = $tier->{'price'};
    $info{'hostname'} = $Config{'general'}{'hostname'} || $Default_Config{'general'}{'hostname'};
    $info{'domain'} = $Config{'general'}{'domain'} || $Default_Config{'general'}{'domain'};
    $info{'subject'} = i18n_format("%s: Network Access Order Confirmation", $Config{'general'}{'domain'});

    #Hove to decide about the transacion id
#    $info{'transaction_id'} = $transaction_infos_ref->{'id'};

    return %info;
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
