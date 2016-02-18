package pf::web::guest;

=head1 NAME

pf::web::guest - module to handle guest portions of the captive portal

=cut

=head1 DESCRIPTION

pf::web::guest contains the functions necessary to generate different guest-related web pages:
based on pre-defined templates: login, registration, release, error, status.

It is possible to customize the behavior of this module by redefining its subs in pf::web::custom.
See F<pf::web::custom> for details.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following template files: F<release.html>,
F<login.html>, F<enabler.html>, F<error.html>, F<status.html>,
F<register.html>.

=cut

use strict;
use warnings;

use Encode;
use File::Basename;
use HTML::Entities;
use Net::LDAP;
use POSIX;
use Readonly;
use Template;
use Text::CSV;
use Try::Tiny;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw();
}

use pf::log;
use pf::constants;
use pf::config;
use pf::password;
use pf::util;
use pf::web qw(i18n ni18n i18n_format render_template);
use pf::web::constants;
use pf::web::util;
use pf::activation;
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::person;

our $VERSION = 1.41;

our $PREREGISTRATION_CONFIRMED_TEMPLATE = 'guest/preregistration.html';
our $EMAIL_CONFIRMED_TEMPLATE = "activated.html";
our $EMAIL_PREREG_CONFIRMED_TEMPLATE = 'guest/preregistration_confirmation.html';
our $SPONSOR_CONFIRMED_TEMPLATE = "activation/sponsor_accepted.html";
our $SPONSOR_LOGIN_TEMPLATE = "activation/sponsor_login.html";

# flag used in URLs
Readonly our $GUEST_REGISTRATION => "guest-register";

# Available default email templates
Readonly our $TEMPLATE_EMAIL_GUEST_ACTIVATION => 'guest_email_activation';
Readonly our $TEMPLATE_EMAIL_SPONSOR_ACTIVATION => 'guest_sponsor_activation';
Readonly our $TEMPLATE_EMAIL_SPONSOR_CONFIRMED => 'guest_sponsor_confirmed';
Readonly our $TEMPLATE_EMAIL_EMAIL_PREREGISTRATION => 'guest_email_preregistration';
Readonly our $TEMPLATE_EMAIL_EMAIL_PREREGISTRATION_CONFIRMED => 'guest_email_preregistration_confirmed';
Readonly our $TEMPLATE_EMAIL_SPONSOR_PREREGISTRATION => 'guest_sponsor_preregistration';
Readonly our $TEMPLATE_EMAIL_GUEST_ADMIN_PREREGISTRATION => 'guest_admin_pregistration';
Readonly our $TEMPLATE_EMAIL_LOCAL_ACCOUNT_CREATION => 'guest_local_account_creation';

our $EMAIL_FROM = undef;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=item aup

Return the Acceptable User Policy (AUP) defined in the template file
/usr/local/pf/html/captive-portal/templates/aup_text.html

=cut

sub aup {
    my $logger = get_logger();

    my $html;
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });
    $template->process( 'aup_text.html', undef, \$html ) || $logger->error($template->error());

    return $html;
}

=item send_template_email

=cut

sub send_template_email {
    my ($template, $subject, $info) = @_;
    my $logger = get_logger();

    my $smtpserver = $Config{'alerting'}{'smtpserver'};
    # local override (EMAIL_FROM) or pf.conf's value or root@domain
    my $from = $pf::web::guest::EMAIL_FROM || $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn;

    my $import_succesfull = try { require MIME::Lite::TT; };
    if (!$import_succesfull) {
        $logger->error(
            "Could not send email because I couldn't load a module. ".
            "Are you sure you have MIME::Lite::TT installed?"
        );
        return $FALSE;
    }

    my %TmplOptions = (
        INCLUDE_PATH    => "$conf_dir/templates/",
        ENCODING        => 'utf8',
    );
    utf8::decode($subject);
    my $msg = MIME::Lite::TT->new(
        From        =>  $from,
        To          =>  $info->{'email'},
        Cc          =>  $info->{'cc'},
        Subject     =>  encode("MIME-Header", $subject),
        Template    =>  "emails-$template.html",
        TmplOptions =>  \%TmplOptions,
        TmplParams  =>  $info,
        TmplUpgrade =>  1,
    );
    $msg->attr("Content-Type" => "text/html; charset=UTF-8;");

    $msg->send('smtp', $smtpserver, Timeout => 20)
        or $logger->warn("problem sending guest registration email");
}

=back

=head1 ERROR STRINGS

=over

=cut

package GUEST;

=item error_code

PacketFence error codes regarding guests.

=cut

Readonly::Scalar our $ERROR_INVALID_FORM => 1;
Readonly::Scalar our $ERROR_EMAIL_UNAUTHORIZED_AS_GUEST => 2;
Readonly::Scalar our $ERROR_CONFIRMATION_EMAIL => 3;
Readonly::Scalar our $ERROR_CONFIRMATION_SMS => 4;
Readonly::Scalar our $ERROR_MISSING_MANDATORY_FIELDS => 5;
Readonly::Scalar our $ERROR_ILLEGAL_EMAIL => 6;
Readonly::Scalar our $ERROR_ILLEGAL_PHONE => 7;
Readonly::Scalar our $ERROR_AUP_NOT_ACCEPTED => 8;
Readonly::Scalar our $ERROR_SPONSOR_NOT_FROM_LOCALDOMAIN => 9;
Readonly::Scalar our $ERROR_SPONSOR_UNABLE_TO_VALIDATE => 10;
Readonly::Scalar our $ERROR_SPONSOR_NOT_ALLOWED => 11;
Readonly::Scalar our $ERROR_PREREG_NOT_ALLOWED => 12;
Readonly::Scalar our $ERROR_INVALID_PIN => 13;
Readonly::Scalar our $ERROR_MAX_RETRIES => 14;

=item errors

An hash mapping error codes to error messages.

=cut

Readonly::Hash our %ERRORS => (
    $ERROR_INVALID_FORM => 'Missing mandatory parameter or malformed entry',
    $ERROR_EMAIL_UNAUTHORIZED_AS_GUEST => q{You can't register as a guest with a %s email address. Please register as a regular user using your email address instead.},
    $ERROR_CONFIRMATION_EMAIL => 'An error occured while sending the confirmation email.',
    $ERROR_CONFIRMATION_SMS => 'An error occured while sending the PIN by SMS.',
    $ERROR_MISSING_MANDATORY_FIELDS => 'Missing mandatory parameter(s): %s',
    $ERROR_ILLEGAL_EMAIL => 'Illegal email address provided',
    $ERROR_ILLEGAL_PHONE => 'Illegal phone number provided',
    $ERROR_AUP_NOT_ACCEPTED => 'Acceptable Use Policy (AUP) was not accepted',
    $ERROR_SPONSOR_NOT_FROM_LOCALDOMAIN => 'Your access can only be sponsored by a %s email address',
    $ERROR_SPONSOR_UNABLE_TO_VALIDATE => 'Unable to validate your sponsor at the moment',
    $ERROR_SPONSOR_NOT_ALLOWED  => 'Email %s is not allowed to sponsor guest access',
    $ERROR_PREREG_NOT_ALLOWED  => 'Guest pre-registration is not allowed by policy',
    $ERROR_INVALID_PIN => 'PIN is Invalid!',
    $ERROR_MAX_RETRIES => 'Maximum amount of retries attempted',
);

=back

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

1;
