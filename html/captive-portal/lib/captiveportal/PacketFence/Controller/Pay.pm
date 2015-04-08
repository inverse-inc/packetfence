package captiveportal::PacketFence::Controller::Pay;
use Moose;
use namespace::autoclean;
use pf::config;
use URI::Escape::XS qw(uri_escape uri_unescape);
use Digest::SHA qw(sha256_hex);
use pf::billing::constants qw($MIRAPAY_ACTION_CODE_APPROVED);
use pf::billing::custom;
use pf::config;
use pf::constants;
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
use List::Util qw(pairmap);

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Pay - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 begin

=cut

sub begin : Private {
    my ( $self, $c ) = @_;
    if( isdisabled($c->profile->getBillingEngine) ) {
        $c->response->redirect("/captive-portal?destination_url=".uri_escape($c->portalSession->profile->getRedirectURL));
        $c->detach;
    }
    $c->forward(CaptivePortal => 'validateMac');
}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $request = $c->request;
    if ($Config{'billing'}{'gateway'} eq 'mirapay_iframe') {
        $c->detach('mirapay_iframe');
    }
    if ( $request->method eq 'POST' ) {
        $c->detach('processBilling');
    }
    for my $p ('firstname', 'lastname', 'email', 'ccnumber', 'ccexpiration', 'ccvalidation') {
        $c->request->param($p => undef);
    }
    $c->forward('showBilling');
}

sub processBilling : Private {
    my ( $self, $c ) = @_;
    $c->forward('validateBilling');
    $c->forward('processTransaction');
}

sub validateBilling : Private {
    my ( $self, $c ) = @_;
    my $portalSession = $c->portalSession;
    my $logger = $c->log;

    # First blast for portalSession object consumption
    my $request = $c->request();

    # Fetch available tiers hash to check if the tier in param is ok
    my $billingObj = new pf::billing::custom();
    my %available_tiers = $billingObj->getAvailableTiers();

    # Check if every field are correctly filled
    if ( $request->param("firstname") && $request->param("lastname") && $request->param("email") &&
         $request->param("ccnumber") && $request->param("ccexpiration") && $request->param("ccverification") &&
         $request->param("tier") && $request->param("aup_signed") ) {

        my $valid_name = ( pf::web::util::is_name_valid($request->param('firstname'))
                && pf::web::util::is_name_valid($request->param('lastname')) );
        my $valid_email = pf::web::util::is_email_valid($request->param('email'));
        my $valid_tier = exists $available_tiers{$request->param("tier")};

        my $valid_ccnumber = pf::web::util::is_creditcardnumber_valid($request->param('ccnumber'));
        my $valid_ccexpiration = pf::web::util::is_creditcardexpiration_valid($request->param('ccexpiration'));
        my $valid_ccverification = pf::web::util::is_creditcardverification_valid($request->param('ccverification'));

        # Provided credit card informations are invalid
        unless ( $valid_ccnumber && $valid_ccexpiration && $valid_ccverification ) {
            # Return non-successful validation with credit card informations error
            $c->stash->{'txt_validation_error'} = $BILLING::ERRORS{$BILLING::ERROR_CC_VALIDATION};
            $c->detach('showBilling');
        }

        # Provided personnal informations are valid
        if ( $valid_name && $valid_email && $valid_tier ) {
            # save personnal informations (no credit card infos) in session
            # so that we will use them to create a guest user and an entry in the database
            $c->session(
                "firstname" => $request->param("firstname"),
                "lastname"  => $request->param("lastname"),
                "email"     => $request->param("email"),
                "login"     => $request->param("email"),
                "tier"      => $request->param("tier"),
            );
        }
    }
    else{
        $c->stash->{'txt_validation_error'} = $BILLING::ERRORS{$BILLING::ERROR_INVALID_FORM};
        $c->detach('showBilling');
    }
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
        $c->forward('processSuccessPayment',[$tier, $transaction_infos_ref]);

    } else { # There was an error with the payment processing
        $logger->warn(
            "There was an error with the payment processing for email $transaction_infos_ref->{email} "
              . "(MAC: $transaction_infos_ref->{mac})");
        $c->stash->{'txt_validation_error'} = $BILLING::ERRORS{$BILLING::ERROR_PAYMENT_GATEWAY_FAILURE};
        $c->detach('showBilling');
    }
}

sub showBilling : Private {
    my ( $self, $c) = @_;
    my ( $portalSession, $error_code ) = @_;
    my $logger = $c->log;
    my $request = $c->request;

    my $billingObj  = new pf::billing::custom();
    my %tiers       = $billingObj->getAvailableTiers();

    $c->stash({
        'tiers' => \%tiers,
        'selected_tier' => $request->param_encoded("tier") || '',
        'firstname' => $request->param_encoded("firstname") || '',
        'lastname' => $request->param_encoded("lastname") || '',
        'email' => $request->param_encoded("email") || '',
        'ccnumber' => $request->param_encoded("ccnumber") || '',
        'ccexpiration' => $request->param_encoded("ccexpiration") || '',
        'ccverification' => $request->param_encoded("ccverification") || '',
        'template' => 'billing/billing.html',
    });

}

sub processSuccessPayment : Private {
    my ($self, $c, $tier, $transaction_infos_ref) = @_;
    my $session       = $c->session;
    my $pid           = $session->{'login'};
    my $profile       = $c->profile;
    my $logger        = $c->log;
    my $request       = $c->request;
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;
    my $billingObj    = new pf::billing::custom();
    my %tiers_infos   = $billingObj->getAvailableTiers();
    my $tiers_info = $tiers_infos{$tier};

    # Adding person (using modify in case person already exists)
    person_modify(
        $pid,
        (   'firstname' => $session->{'firstname'},
            'lastname'  => $session->{'lastname'},
            'email'     => lc($session->{'email'}),
            'notes'     => 'billing engine activation - ' . $tier,
            'portal'    => $profile->getName,
            'source'    => 'billing',
        )
    );

    my %info;
    $c->forward('update_node_time_balance', [$mac,$transaction_infos_ref,$tiers_info,\%info]);
    $c->forward('close_violations', [$mac]);

    # Register the node
    $c->forward('CaptivePortal' => 'webNodeRegister', [$info{pid}, %info]);

    my $confirmationInfo = {
        tier      => $session->{'tier'},
        firstname => $session->{'firstname'},
        lastname  => $session->{'lastname'},
        email     => $session->{'email'},
    };
    $c->forward('send_billing_email' => [$transaction_infos_ref, $confirmationInfo]);

    # Generate the release page
    # XXX Should be part of the portal profile

    $c->forward('CaptivePortal' => 'endPortalSession');
}


=head2 update_node_time_balance

Update node time balance

=cut

sub update_node_time_balance : Private {
    my ($self, $c, $mac, $transaction_infos_ref, $tiers_info, $info) = @_;
    my $logger = $c->log;
    my $pid           = $c->session->{'login'};
    # Grab additional infos about the node
    my $timeout = normalize_time($tiers_info->{'timeout'});
    $info->{'pid'}      = $pid;
    $info->{'category'} = $tiers_info->{'category'};
    $info->{'unregdate'} =
      POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime(time + $timeout));

    if ($tiers_info->{'usage_duration'}) {
        $info->{'time_balance'} =
          normalize_time($tiers_info->{'usage_duration'});

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
    return ;
}


=head2 send_billing_email

Send the billing email

=cut

sub send_billing_email : Private {
    my ($self, $c, $transaction_infos_ref, $confirmationInfo) = @_;
    my $billingObj  = new pf::billing::custom();

    # Send confirmation email
    my %data = $billingObj->prepareConfirmationInfo($transaction_infos_ref, $confirmationInfo);
    pf::util::send_email('billing_confirmation', $data{'email'}, $data{'subject'}, \%data);
    return;
}

=head2 close_violations

CLose all violations for this mac

=cut

sub close_violations : Private {
    my ($self,$c,$mac) = @_;

    # Close violations that use the 'Accounting::BandwidthExpired' trigger
    my @tid = trigger_view_tid($ACCOUNTING_POLICY_TIME);
    foreach my $violation (@tid) {

        # Close any existing violation
        violation_force_close($mac, $violation->{'vid'});
    }
    return ;
}

=head2 mirapay_iframe

=cut

sub mirapay_iframe : Private {
    my ($self, $c) = @_;
    $c->forward('showBilling');
    $c->stash(
        template => 'billing/mirapay_iframe_choose.html',
        txt_validation_error => $c->request->param_encoded('txt_validation_error')
    );
}

=head2 mirapay_iframe_pay

=cut

sub mirapay_iframe_pay : Local {
    my ($self, $c) = @_;
    $c->forward('mirapay_iframe_verify_input');
    my $session = $c->session;
    my $portalSession = $c->portalSession;

    # First blast for portalSession object consumption
    my $request = $c->request();

    # Fetch available tiers hash to check if the tier in param is ok
    my $billingObj            = new pf::billing::custom();
    my %available_tiers       = $billingObj->getAvailableTiers();
    my $tier                  = $request->param('tier');
    my %tiers_infos           = $billingObj->getAvailableTiers();
    my $mac                   = $portalSession->clientMac;
    $session->{tier} = $tier;
    $session->{firstname} = $request->param('firstname');
    $session->{lastname} = $request->param('lastname');
    $session->{email} = $request->param('email');
    $session->{login} = $request->param('email');
    my $transaction_infos_ref = {
        ip          => $portalSession->clientIp(),
        mac         => $mac,
        item        => $tier,
        price       => $tiers_infos{$tier}{'price'},
        description => $tiers_infos{$tier}{'description'},
    };
    $c->stash(
        template    => 'billing/mirapay_iframe_pay.html',
        mirapay_url => $self->_build_mirapay_url($c, $transaction_infos_ref)
    );
}

=head2 _build_mirapay_url

=cut

sub _build_mirapay_url {
    my ($self, $c, $transaction_infos_ref) = @_;
    my $request      = $c->request;
    my $billing      = $Config{billing};
    my $url          = $billing->{mirapay_iframe_url};
    my $merchant_id  = $billing->{mirapay_iframe_merchant_id};
    my $cardholdername = $request->param('firstname') . ' ' . $request->param('lastname') ;
    my $redirect_url = "https://" . join(".",$Config{general}{hostname},$Config{general}{domain}) . "/pay/mirapay_iframe_process";
    my @params       = (
        MerchantID  => $merchant_id,
        RedirectURL => $redirect_url,
        EchoData    => $transaction_infos_ref->{item},
        Amount      => $transaction_infos_ref->{price} * 100
    );
    my $mkey = $self->calc_mkey($c, @params);
    my $query = join("&", pairmap {"$a=" . uri_escape($b)} @params, 'MKEY', $mkey);
    return "$url?$query";
}

=head2 mirapay_iframe_process

=cut

sub mirapay_iframe_process : Local {
    my ($self, $c) = @_;
    if ($self->_mirapay_verify_request($c)) {
        $c->stash->{template} = 'billing/mirapay_iframe_process.html';
    }
    else {
        $c->stash->{template} = 'billing/mirapay_iframe_process_error.html';
    }
}

=head2 mirapay_iframe_process_success

=cut

sub mirapay_iframe_process_success : Local {
    my ($self, $c) = @_;
    my $billingObj    = new pf::billing::custom();
    my $request       = $c->request;
    my $session       = $c->session;
    my $logger        = $c->log;
    my $portalSession = $c->portalSession;
    my $profile       = $c->profile;
    my $mac           = $portalSession->clientMac;
    my $approval_code = $request->param('ApprovalCode');
    my $bank_response = $request->param('BankResponse');
    my $cvv_response  = $request->param('CVVResponse');
    my $date_time     = $request->param('DateTime');
    my $avs_response  = $request->param('AVSResponse');

    # Transactions informations
    my $tier                  = $session->{'tier'};
    my %tiers_infos           = $billingObj->getAvailableTiers();
    my $transaction_infos_ref = {
        ip          => $portalSession->clientIp(),
        mac         => $mac,
        firstname   => $session->{'firstname'},
        lastname    => $session->{'lastname'},
        email       => lc($session->{'email'}),
        item        => $tier,
        price       => $tiers_infos{$tier}{'price'},
        description => $tiers_infos{$tier}{'description'},
    };
    $c->forward('processSuccessPayment', [$tier, $transaction_infos_ref]);
}

our %MirapayResponseCode = (
    01 => 'Approved',
    10 => 'Invalid MKEY',
    11 => 'Bad Session',
    12 => 'Session Expired',
    13 => 'Bad TransactionID',
    14 => 'Bad Amount',
    15 => 'Bad TermID Group',
    16 => 'Bad Statement Descriptor',
    17 => 'Duplicate submission',
    18 => 'Invalid Origin Server',
    20 => 'Authorization Failed',
    30 => 'No Token',
    80 => 'VBV Error',
    81 => 'VBV Declined',
    82 => 'VBV Invalid Merchant Config',
);



=head2 _mirapay_verify_request

=cut

sub _mirapay_verify_request {
    my ($self, $c) = @_;
    my $request = $c->request;
    my $action_code = $request->param('ActionCode');
    my $response_code = $request->param('ResponseCode');
    if($action_code ne $MIRAPAY_ACTION_CODE_APPROVED) {
        $c->stash->{'txt_validation_error'} = $MirapayResponseCode{$response_code};
        return $FALSE;
    }
    return $TRUE;
}


=head2 mirapay_iframe_verify_input

=cut

sub mirapay_iframe_verify_input : Private {
    my ($self,$c) = @_;
    my $portalSession = $c->portalSession;
    my $logger = $c->log;

    # First blast for portalSession object consumption
    my $request = $c->request();

    # Fetch available tiers hash to check if the tier in param is ok
    my $billingObj = new pf::billing::custom();
    my %available_tiers = $billingObj->getAvailableTiers();
    if (   $request->param("firstname")
        && $request->param("lastname")
        && $request->param("email")
        && $request->param("tier")
        && $request->param("aup_signed")) {
        my $valid_name = ( pf::web::util::is_name_valid($request->param('firstname'))
                && pf::web::util::is_name_valid($request->param('lastname')) );
        my $valid_email = pf::web::util::is_email_valid($request->param('email'));
        my $valid_tier = exists $available_tiers{$request->param("tier")};
        # Provided personnal informations are valid
        if ( $valid_name && $valid_email && $valid_tier ) {
            # so that we will use them to create a guest user and an entry in the database
            $c->session(
                "firstname" => $request->param("firstname"),
                "lastname"  => $request->param("lastname"),
                "email"     => $request->param("email"),
                "login"     => $request->param("email"),
                "tier"      => $request->param("tier"),
            );
        }
    }
    else {
        $c->stash->{'txt_validation_error'} = $BILLING::ERRORS{$BILLING::ERROR_INVALID_FORM};
        $c->stash->{template} = 'billing/mirapay_iframe_process_error.html';
        $c->detach();
    }
    return;
}


=head2 calc_mkey

Calaulate the mkey from parameters given

=cut

sub calc_mkey {
    my ($self,$c,@params) = @_;
    sha256_hex(@params,$Config{billing}{mirapay_iframe_shared_secret});
}


=head2 _verify_mkey

Verify the mkey provide back from mirapay
Concat all the query names and values into one string (except MKEY)
Append the shared secret digest it using sha_256 and compare the results with the MKEY

=cut

sub _verify_mkey {
    my ($self,$c) = @_;
    my $logger = $c->log;
    my $query = $c->request->uri->query;
    my @params;
    for my $item (split ('&',$query)) {
        my ($name,$value) = split ('=',$item);
        push @params, uri_unescape($name),uri_unescape($value // '');
    }
    my $mkey = pop @params;
    my $name = pop @params;
    if ($name ne 'MKEY') {
         $logger->error("Invalid query the last query parameter is not MKEY $query");
         return 0;
    }
    my $test_key = $self->calc_mkey(@params);
    return $test_key eq $mkey ;
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

1;
