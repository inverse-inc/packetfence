package pf::web::billing;

=head1 NAME

pf::web::billing - module to handle billing engine portion pf the captive portal

=cut

=head1 DESCRIPTION

pf::web::billing contains the functions necessaries to generate different billing-related web pages:
based on pre-defined templates:

It is possible to customize the behavior of this module by redefining its subs in pf::web::custom.
See F<pf::web::custom> for details.

=cut

use strict;
use warnings;

use Encode;
use HTML::Entities;
use HTTP::Request::Common qw(POST);
use Log::Log4perl;
use LWP::UserAgent;
use Template;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw();
}

use pf::billing::constants;
use pf::billing::custom;
use pf::config;
use pf::web qw(i18n ni18n render_template);
use pf::web::util;

our $VERSION = 1.00;

=head1 SUBROUTINES

=over

=cut


=item generate_billing_page

Generate the template to present a billing page to users so that they can pay for getting network access
Will produce billing.html

=cut

sub generate_billing_page {
    my ( $portalSession, $error_code ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $billingObj  = new pf::billing::custom();
    my %tiers       = $billingObj->getAvailableTiers();

    $portalSession->stash({
        'tiers' => \%tiers,
        'selected_tier' => $portalSession->cgi->param("tier"),
        'firstname' => $portalSession->cgi->param("firstname"),
        'lastname' => $portalSession->cgi->param("lastname"),
        'email' => $portalSession->cgi->param("email"),
        'ccnumber' => $portalSession->cgi->param("ccnumber"),
        'ccexpiration' => $portalSession->cgi->param("ccexpiration"),
        'ccverification' => $portalSession->cgi->param("ccverification"),

    });

    # Error management
    $portalSession->stash->{'txt_validation_error'} = $BILLING::ERRORS{$error_code} if (defined($error_code));

    # Generating the page with the correct template
    $logger->info('generate_billing_page');
    render_template($portalSession, 'billing/billing.html');
    exit;
}

=item validate_billing_infos

=cut

sub validate_billing_infos {
    my ( $portalSession ) = @_;
    my $logger = Log::Log4perl::get_logger();

    # First blast for portalSession object consumption
    my $cgi = $portalSession->getCgi();
    my $session = $portalSession->getSession();

    # Fetch available tiers hash to check if the tier in param is ok
    my $billingObj = new pf::billing::custom();
    my %available_tiers = $billingObj->getAvailableTiers();

    # Check if every field are correctly filled
    if ( $cgi->param("firstname") && $cgi->param("lastname") && $cgi->param("email") &&
         $cgi->param("ccnumber") && $cgi->param("ccexpiration") && $cgi->param("ccverification") &&
         $cgi->param("tier") && $cgi->param("aup_signed") ) {

        my $valid_name = ( pf::web::util::is_name_valid($cgi->param('firstname'))
                && pf::web::util::is_name_valid($cgi->param('lastname')) );
        my $valid_email = pf::web::util::is_email_valid($cgi->param('email'));
        my $valid_tier = exists $available_tiers{$cgi->param("tier")};

        my $valid_ccnumber = pf::web::util::is_creditcardnumber_valid($cgi->param('ccnumber'));
        my $valid_ccexpiration = pf::web::util::is_creditcardexpiration_valid($cgi->param('ccexpiration'));
        my $valid_ccverification = pf::web::util::is_creditcardverification_valid($cgi->param('ccverification'));

        # Provided credit card informations are invalid
        unless ( $valid_ccnumber && $valid_ccexpiration && $valid_ccverification ) {
            # Return non-successful validation with credit card informations error
            return ($FALSE, $BILLING::ERROR_CC_VALIDATION);
        }

        # Provided personnal informations are valid
        if ( $valid_name && $valid_email && $valid_tier ) {
            # save personnal informations (no credit card infos) in session
            # so that we will use them to create a guest user and an entry in the database
            $session->param("firstname", $cgi->param("firstname"));
            $session->param("lastname", $cgi->param("lastname"));
            $session->param("email", $cgi->param("email"));
            $session->param("login", $cgi->param("email"));
            $session->param("tier", $cgi->param("tier"));

            # Return a successful validation
            return ($TRUE, 0);
        }
    }

    # Return an unsuccessful validation with incorrect or incomplete informations error
    return ($FALSE, $BILLING::ERROR_INVALID_FORM);
}


=back

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

1;
