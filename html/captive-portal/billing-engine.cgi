#!/usr/bin/perl

=head1 NAME

billing-engine.cgi - billing engine portal

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

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
use pf::util;
use pf::violation;
use pf::web;
use pf::web::billing 1.00;
# called last to allow redefinitions
use pf::web::custom;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('billing-engine.cgi');
Log::Log4perl::MDC->put('proc', 'billing-engine.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $portalSession = pf::Portal::Session->new();
my $cgi = $portalSession->getCgi();

# If the billing engine isn't enabled (you shouldn't be here), redirect to portal entrance
print $cgi->redirect("/captive-portal?destination_url=".uri_escape($portalSession->getDestinationUrl()))
    if ( isdisabled($Config{'registration'}{'billing_engine'}) );

# we need a valid MAC to identify a node
if ( !valid_mac($portalSession->getClientMac()) ) {
    $logger->info($portalSession->getClientIp() . " not resolvable, generating error page");
    pf::web::generate_error_page($portalSession, i18n("error: not found in the database"));
    exit(0);
}

if ( defined($cgi->param('submit')) ) {

    # Validate the form
    my ($validation_return, $error_code) = pf::web::billing::validate_billing_infos($portalSession);

    # Form is valid (Provided infos are ok)
    if ( $validation_return ) {

        my $billingObj = new pf::billing::custom();

        # Transactions informations
        my $tier                  = $cgi->param('tier');
        my %tiers_infos           = $billingObj->getAvailableTiers();
        my $transaction_infos_ref = {
                ip              => $portalSession->getClientIp(),
                mac             => $portalSession->getClientMac(),
                firstname       => $cgi->param('firstname'),
                lastname        => $cgi->param('lastname'),
                email           => lc($cgi->param('email')),
                ccnumber        => $cgi->param('ccnumber'),
                ccexpiration    => $cgi->param('ccexpiration'),
                ccverification  => $cgi->param('ccverification'),
                item            => $tier,
                price           => $tiers_infos{$tier}{'price'},
                description     => $tiers_infos{$tier}{'description'},
        };

        # Process the transaction
        my $paymentStatus   = $billingObj->processTransaction($transaction_infos_ref);

        if ( $paymentStatus eq $BILLING::SUCCESS ) {
            # Adding person (using modify in case person already exists)
            person_modify($portalSession->getSession->param('login'), (
                    'firstname' => $cgi->param('firstname'),
                    'lastname'  => $cgi->param('lastname'),
                    'email'     => lc($cgi->param('email')),
                    'notes'     => 'billing engine activation - ' . $tier,
            ));

            # Grab additional infos about the node
            my %info;
            my $timeout         = normalize_time($tiers_infos{$tier}{'timeout'});
            $info{'pid'}        = $portalSession->getSession->param('login');
            $info{'category'}   = $tiers_infos{$tier}{'category'};
            $info{'unregdate'}  = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime( time + $timeout ));

            # Register the node
            pf::web::web_node_register($portalSession, $info{'pid'}, %info);

            # Generate the release page
            # XXX Should be part of the portal profile
            $portalSession->setDestinationUrl(decode_entities(uri_unescape($tiers_infos{$tier}{'destination_url'})))
                if ($tiers_infos{$tier}{'destination_url'});
            
            pf::web::end_portal_session($portalSession);
        } 
        # There was an error with the payment processing
        else {
            $logger->warn(
                "There was an error with the payment processing for email $transaction_infos_ref->{email} "
                . "(MAC: $transaction_infos_ref->{mac})"
            );

            pf::web::billing::generate_billing_page($portalSession, $BILLING::ERROR_PAYMENT_GATEWAY_FAILURE);
            exit(0);
        }            
    }

    # The form was invalid, return to the billing page and show error message
    if ( !$validation_return ) {
        $logger->info("Billing form was invalid, return to the billing page.");
        pf::web::billing::generate_billing_page($portalSession, $error_code);
        exit(0);
    }

}

# The form haven't been submitted yet
else {
    # Wipe web fields if exists
    $cgi->delete('firstname', 'lastname', 'email', 'ccnumber', 'ccexpiration', 'ccvalidation');

    # By default, show billing page
    pf::web::billing::generate_billing_page($portalSession);
}

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
