package captive::portal::Controller::Pay;
use Moose;
use namespace::autoclean;
use pf::config;
use HTML::Entities;
use Log::Log4perl;
use POSIX;
use URI::Escape qw(uri_escape uri_unescape);

use pf::billing::constants;
use pf::billing::custom;
use pf::config;
use pf::iplog;
use pf::node;
use pf::person qw(person_modify);
use pf::Portal::Session;
use pf::radius::constants;
use pf::util;
use pf::violation;
use pf::web;
use pf::web::billing 1.00;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

captive::portal::Controller::Pay - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $request       = $c->req;
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;
    my $logger        = $c->log;
    if ( defined( $request->param('submit') ) ) {

        # Validate the form
        my ( $validation_return, $error_code ) =
          $self->validate_billing_infos($c);

        # Form is valid (Provided infos are ok)
        if ($validation_return) {

            my $billingObj = new pf::billing::custom();

            # Transactions informations
            my $tier                  = $request->param('tier');
            my %tiers_infos           = $billingObj->getAvailableTiers();
            my $transaction_infos_ref = {
                ip             => $portalSession->clientIp(),
                mac            => $mac,
                firstname      => $request->param('firstname'),
                lastname       => $request->param('lastname'),
                email          => lc( $request->param('email') ),
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

            if ( $paymentStatus eq $BILLING::SUCCESS ) {

                # Adding person (using modify in case person already exists)
                person_modify(
                    $c->session->{'login'},
                    (   'firstname' => $request->param('firstname'),
                        'lastname'  => $request->param('lastname'),
                        'email'     => lc( $request->param('email') ),
                        'notes'     => 'billing engine activation - ' . $tier,
                    )
                );

                # Grab additional infos about the node
                my %info;
                my $timeout =
                  normalize_time( $tiers_infos{$tier}{'timeout'} );
                $info{'pid'}       = $c->session->param('login');
                $info{'category'}  = $tiers_infos{$tier}{'category'};
                $info{'unregdate'} = POSIX::strftime( "%Y-%m-%d %H:%M:%S",
                    localtime( time + $timeout ) );

                if ( $tiers_infos{$tier}{'usage_duration'} ) {
                    $info{'timeleft'} =
                      normalize_time( $tiers_infos{$tier}{'usage_duration'} );

                    # Check if node has some access time left; if so, add it to the new duration
                    my $node = node_view($mac);
                    if ( $node && $node->{'timeleft'} > 0 ) {
                        if ( $node->{'last_start_timestamp'} > 0 ) {

                            # Node is active; compute the actual access time left
                            my $expiration = $node->{'last_start_timestamp'}
                              + $node->{'timeleft'};
                            my $now = time;
                            if ( $expiration > $now ) {
                                $info{'timeleft'} += ( $expiration - $now );
                            }
                        } else {

                            # Node is inactive; add the remaining access time to the purchased access time
                            $info{'timeleft'} += $node->{'timeleft'};
                        }
                    }
                    $logger->info( "Usage duration for $mac is now "
                          . $info{'timeleft'} );
                }

                # Close any existing violation
                violation_force_close( $mac, $RADIUS::EXPIRATION_VID );

                # Register the node
                pf::web::web_node_register( $portalSession, $info{'pid'},
                    %info );

                # Send confirmation email
                my %data =
                  $billingObj->prepareConfirmationInfo(
                    $transaction_infos_ref, $portalSession );
                pf::util::send_email( 'billing_confirmation', $data{'email'},
                    $data{'subject'}, \%data );

                # Generate the release page
                # XXX Should be part of the portal profile
                $portalSession->setDestinationUrl(
                    decode_entities(
                        uri_unescape(
                            $tiers_infos{$tier}{'destination_url'}
                        )
                    )
                ) if ( $tiers_infos{$tier}{'destination_url'} );

                pf::web::end_portal_session($portalSession);
            }

            # There was an error with the payment processing
            else {
                $logger->warn(
                    "There was an error with the payment processing for email $transaction_infos_ref->{email} "
                      . "(MAC: $transaction_infos_ref->{mac})" );

                pf::web::billing::generate_billing_page( $portalSession,
                    $BILLING::ERROR_PAYMENT_GATEWAY_FAILURE );
                exit(0);
            }
        }

        # The form was invalid, return to the billing page and show error message
        if ( !$validation_return ) {
            $logger->info(
                "Billing form was invalid, return to the billing page.");
            pf::web::billing::generate_billing_page( $portalSession,
                $error_code );
            exit(0);
        }

    }

}

sub validate_billing_infos {
    my ( $self, $c ) = @_;
    my $logger = Log::Log4perl::get_logger();

    # First blast for portalSession object consumption
    my $request = $c->req();

    # Fetch available tiers hash to check if the tier in param is ok
    my $billingObj      = new pf::billing::custom();
    my %available_tiers = $billingObj->getAvailableTiers();

    # Check if every field are correctly filled
    if (   $request->param("firstname")
        && $request->param("lastname")
        && $request->param("email")
        && $request->param("ccnumber")
        && $request->param("ccexpiration")
        && $request->param("ccverification")
        && $request->param("tier")
        && $request->param("aup_signed") ) {

        my $valid_name =
          (      pf::web::util::is_name_valid( $request->param('firstname') )
              && pf::web::util::is_name_valid( $request->param('lastname') )
          );
        my $valid_email =
          pf::web::util::is_email_valid( $request->param('email') );
        my $valid_tier = exists $available_tiers{ $request->param("tier") };

        my $valid_ccnumber = pf::web::util::is_creditcardnumber_valid(
            $request->param('ccnumber') );
        my $valid_ccexpiration = pf::web::util::is_creditcardexpiration_valid(
            $request->param('ccexpiration') );
        my $valid_ccverification =
          pf::web::util::is_creditcardverification_valid(
            $request->param('ccverification') );

        # Provided credit card informations are invalid
        unless ( $valid_ccnumber
            && $valid_ccexpiration
            && $valid_ccverification ) {

            # Return non-successful validation with credit card informations error
            return ( $FALSE, $BILLING::ERROR_CC_VALIDATION );
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

            # Return a successful validation
            return ( $TRUE, 0 );
        }
    }

    # Return an unsuccessful validation with incorrect or incomplete informations error
    return ( $FALSE, $BILLING::ERROR_INVALID_FORM );
}

sub generate_billing_page {
    my ( $c, $error_code ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $billingObj = new pf::billing::custom();
    my %tiers      = $billingObj->getAvailableTiers();

    # Error management
    $c->stash->{'txt_validation_error'} = $BILLING::ERRORS{$error_code}
      if ( defined($error_code) );

    # Generating the page with the correct template
    $logger->info('generate_billing_page');
    my $request = $c->req;
    $c->stash(
        template         => 'billing/billing.html',
        'tiers'          => \%tiers,
        'selected_tier'  => $request->param("tier") || '',
        'firstname'      => $request->param("firstname") || '',
        'lastname'       => $request->param("lastname") || '',
        'email'          => $request->param("email") || '',
        'ccnumber'       => $request->param("ccnumber") || '',
        'ccexpiration'   => $request->param("ccexpiration") || '',
        'ccverification' => $request->param("ccverification") || '',
    );
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
