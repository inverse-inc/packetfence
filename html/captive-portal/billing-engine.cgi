#!/usr/bin/perl

=head1 NAME

billing-engine.cgi - billing engine portal

=cut

use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
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

my $cgi = new CGI;
$cgi->charset("UTF-8");
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});
my $destination_url = pf::web::get_destination_url($cgi);
my $ip = $cgi->remote_addr();

# If the billing engine isn't enabled (you shouldn't be here), redirect to portal entrance
print $cgi->redirect("/captive-portal?destination_url=".uri_escape($destination_url))
        if ( isdisabled($Config{'registration'}{'billing_engine'}) );

# we need a valid MAC to identify a node
# TODO this is duplicated too much, it should be brought up in a global dispatcher
my $mac = ip2mac($ip);
if (!valid_mac($mac)) {
  $logger->info("$ip not resolvable, generating error page");
  pf::web::generate_error_page($cgi, $session, "error: not found in the database");
  exit(0);
}

if ( defined($cgi->param('submit')) ) {

    # Validate the form
    my ($validation_return, $error_code) = pf::web::billing::validate_billing_infos($cgi, $session);

    # Form is valid (Provided infos are ok)
    if ( $validation_return ) {

        my $billingObj = new pf::billing::custom();

        # Transactions informations
        my $tier                  = $cgi->param('tier');
        my %tiers_infos           = $billingObj->getAvailableTiers();
        my $transaction_infos_ref = {
                ip              => $ip,
                mac             => $mac,
                firstname       => $cgi->param('firstname'),
                lastname        => $cgi->param('lastname'),
                email           => $cgi->param('email'),
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
            person_modify($session->param('login'), (
                    'firstname' => $cgi->param('firstname'),
                    'lastname'  => $cgi->param('lastname'),
                    'email'     => $cgi->param('email'),
                    'notes'     => 'billing engine activation - ' . $tier,
            ));

            # Grab additional infos about the node
            my %info;
            my $timeout         = normalize_time($tiers_infos{$tier}{'timeout'});
            $info{'pid'}        = $session->param('login');
            $info{'category'}   = $tiers_infos{$tier}{'category'};
            $info{'unregdate'}  = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime( time + $timeout ));

            # Register the node
            pf::web::web_node_register($cgi, $session, $mac, $info{'pid'}, %info);

            # Generate the release page
            $destination_url = decode_entities(uri_unescape($tiers_infos{$tier}{'destination_url'}))
                    if ( $tiers_infos{$tier}{'destination_url'} );
            
            pf::web::end_portal_session($cgi, $session, $mac, $destination_url);
        } 
        # There was an error with the payment processing
        else {
            $logger->warn(
                "There was an error with the payment processing for email $transaction_infos_ref->{email} "
                . "(MAC: $transaction_infos_ref->{mac})"
            );

            pf::web::billing::generate_billing_page(
                    $cgi, $session, $destination_url, $mac, $BILLING::ERROR_PAYMENT_GATEWAY_FAILURE
            );
            exit(0);
        }            
    }

    # The form was invalid, return to the billing page and show error message
    if ( !$validation_return ) {
        $logger->info("Billing form was invalid, return to the billing page.");
        pf::web::billing::generate_billing_page(
                $cgi, $session, $destination_url, $mac, $error_code
        );
        exit(0);
    }

}

# The form haven't been submitted yet
else {
    # Wipe web fields if exists
    $cgi->delete('firstname', 'lastname', 'email', 'ccnumber', 'ccexpiration', 'ccvalidation');

    # By default, show billing page
    pf::web::billing::generate_billing_page($cgi, $session, $destination_url, $mac);
}


=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2011, 2012 Inverse inc.
    
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
