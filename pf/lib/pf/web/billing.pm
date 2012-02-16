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
use Locale::gettext;
use Log::Log4perl;
use LWP::UserAgent;
use POSIX;
use Template;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw();
}

use pf::billing::custom;
use pf::config;
use pf::web qw(i18n ni18n);
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
    my ( $cgi, $session, $post_uri, $destination_url, $mac, $err ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    setlocale( LC_MESSAGES, pf::web::web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    my $vars = {
        i18n            => \&i18n,
        destination_url => encode_entities($destination_url),
        logo            => $Config{'general'}{'logo'},
        post_uri        => $post_uri,
        list_help_info  => [
            { name => i18n('IP'),   value => $cgi->remote_addr },
            { name => i18n('MAC'),  value => $mac }
        ],
    };

    my $billingObj  = new pf::billing::custom();
    my %tiers       = $billingObj->getAvailableTiers();

    $vars->{'tiers'}            = \%tiers;
    $vars->{'firstname'}        = $cgi->param("firstname");
    $vars->{'lastname'}         = $cgi->param("lastname");
    $vars->{'email'}            = $cgi->param("email");
    $vars->{'ccnumber'}         = $cgi->param("ccnumber");
    $vars->{'ccexpiration'}     = $cgi->param("ccexpiration");
    $vars->{'ccverification'}   = $cgi->param("ccverification");

    # Error management
    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_validation_error'} = i18n("Missing mandatory parameter or malformed entry");
        } elsif ( $err == 2 ) {
            $vars->{'txt_validation_error'} = i18n(
                    "An error occured while processing your payment. Incorrect credit card informations provided."
            );
        } elsif ( $err == 3 ) {
            $vars->{'txt_validation_error'} = i18n(
                    "An error occured while processing you payment. Your credit card has not been charged."
            );
        }
    }

    # Generating the page with the correct template
    $logger->info('generate_billing_page');
    my $template = Template->new( { INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}], } );
    $template->process( "billing/billing.html", $vars );
    exit;
}

=item validate_billing_infos

=cut
sub validate_billing_infos {
    my ( $cgi, $session ) = @_;
    my $logger = Log::Log4perl::get_logger();

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
            return (0, 2)
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
            return (1, 0);
        }
    }

    # Return an unsuccessful validation with incorrect or incomplete informations error
    return (0, 1);
}
