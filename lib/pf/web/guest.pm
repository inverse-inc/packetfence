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
use Log::Log4perl;
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

our $SELF_REGISTRATION_TEMPLATE = "guest.html";

our $PREREGISTRATION_CONFIRMED_TEMPLATE = 'guest/preregistration.html';
our $EMAIL_CONFIRMED_TEMPLATE = "activated.html";
our $EMAIL_PREREG_CONFIRMED_TEMPLATE = 'guest/preregistration_confirmation.html';
our $SPONSOR_CONFIRMED_TEMPLATE = "guest/sponsor_accepted.html";
our $SPONSOR_LOGIN_TEMPLATE = "guest/sponsor_login.html";

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
Readonly our $TEMPLATE_EMAIL_GUEST_ON_REGISTRATION => 'guest_registered';
Readonly our $TEMPLATE_EMAIL_LOCAL_ACCOUNT_CREATION => 'guest_local_account_creation';

our $EMAIL_FROM = undef;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=item generate_selfregistration_page

Sub to present to a guest so that it can self-register (guest.html).

=cut

sub generate_selfregistration_page {
    my ( $portalSession, $error_code, $error_args_ref ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web::guest');

    $logger->info('generate_selfregistration_page');

    my $sms_type = pf::Authentication::Source::SMSSource->meta->get_attribute('type')->default;
    my $cgi        = $portalSession->cgi;
    my $profile    = $portalSession->getProfile;
    my $source     = $profile->getSourceByType($sms_type);
    my $guestModes = $profile->getGuestModes;
    my @mandatory_fields    = @{$profile->getMandatoryFields};
    my $email_guest_allowed = is_in_list( $SELFREG_MODE_EMAIL, $guestModes );
    my $sms_guest_allowed   = is_in_list( $SELFREG_MODE_SMS, $guestModes );
    my $sponsored_guest_allowed =
      is_in_list( $SELFREG_MODE_SPONSOR, $guestModes );
    my %field_names = (
        anniversary      => 'Anniversary',
        birthday         => 'Birthday',
        gender           => 'Gender',
        lang             => 'Lang',
        nickname         => 'Nickname',
        organization     => 'Organization',
        cell_phone       => 'Cell Phone',
        work_phone       => 'Work Phone',
        title            => 'Title',
        building_number  => 'Building Number',
        apartment_number => 'Apartment Number',
        room_number      => 'Room Number',
        custom_field_1   => 'Custom Field 1',
        custom_field_2   => 'Custom Field 2',
        custom_field_3   => 'Custom Field 3',
        custom_field_4   => 'Custom Field 4',
        custom_field_5   => 'Custom Field 5',
        custom_field_6   => 'Custom Field 6',
        custom_field_7   => 'Custom Field 7',
        custom_field_8   => 'Custom Field 8',
        custom_field_9   => 'Custom Field 9',
    );

    $portalSession->stash({
        post_uri       => "$WEB::URL_SIGNUP?mode=$GUEST_REGISTRATION",
        firstname      => $cgi->param("firstname") || '',
        lastname       => $cgi->param("lastname") || '',
        organization   => $cgi->param("organization") || '',
        phone          => $cgi->param("phone") || '',
        mobileprovider => $cgi->param("mobileprovider") || '',
        email          => lc( $cgi->param("email") || '' ),
        sponsor_email  => lc( $cgi->param("sponsor_email") || '' ),
        mandatory_fields  => \@mandatory_fields,
        sms_carriers   => sms_carrier_view_all($source),
        email_guest_allowed => $email_guest_allowed,
        sms_guest_allowed => $sms_guest_allowed,
        sponsored_guest_allowed => $sponsored_guest_allowed,
        is_preregistration => $portalSession->session->param('preregistration'),
        field_names => \%field_names,
    });

    # Error management
    if (defined($error_code) && $error_code != 0) {
        # ideally we'll set the array_ref always and won't need the following
        $error_args_ref = [] if (!defined($error_args_ref));
        $portalSession->stash->{'txt_validation_error'} = i18n_format($GUEST::ERRORS{$error_code}, @$error_args_ref);
        utf8::decode($portalSession->stash->{'txt_validation_error'});
    }

    render_template($portalSession, $pf::web::guest::SELF_REGISTRATION_TEMPLATE);
    exit;
}

=item validate_selfregistration

Sub to validate self-registering guests.

=cut

sub validate_selfregistration {
    my ($portalSession) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # First blast at consuming portalSession object
    my $cgi     = $portalSession->getCgi();
    my $session = $portalSession->getSession();
    my $profile = $portalSession->getProfile();

    # is preregistration allowed?
    if ($session->param("preregistration") && isdisabled($Config{'guests_self_registration'}{'preregistration'})) {
        return ($FALSE, $GUEST::ERROR_PREREG_NOT_ALLOWED);
    }

    # mandatory parameters are defined in config
    my @mandatory_fields = @{$profile->getMandatoryFields || []};

    # no matter what is defined as mandatory, these are the minimum fields required per mode
    push @mandatory_fields, ('email') if (defined($cgi->param('by_email')));
    push @mandatory_fields, ('sponsor_email') if (defined($cgi->param('by_sponsor')));
    push @mandatory_fields, ('phone', 'mobileprovider') if (defined($cgi->param('by_sms')));

    # build hashlookup (collapses redundant checks together)
    my %mandatory_fields = map { $_ => $TRUE } @mandatory_fields;

    my @missing_fields;
    foreach my $required_field (keys %mandatory_fields) {
        # mandatory must be non-empty
        push @missing_fields, $required_field if ( !$cgi->param($required_field) );
    }

    # some mandatory fields are missing
    if (@missing_fields) {
        return ( $FALSE, $GUEST::ERROR_MISSING_MANDATORY_FIELDS, [ join(", ", map { i18n($_) } @missing_fields) ] );
    }

    if ( $mandatory_fields{'email'} && !pf::web::util::is_email_valid($cgi->param('email')) ) {
        return ($FALSE, $GUEST::ERROR_ILLEGAL_EMAIL);
    }

    if ( $mandatory_fields{'phone'} && !pf::web::util::validate_phone_number($cgi->param('phone')) ) {
        return ($FALSE, $GUEST::ERROR_ILLEGAL_PHONE);
    }

    if (!length($cgi->param("aup_signed"))) {
        return ($FALSE, $GUEST::ERROR_AUP_NOT_ACCEPTED);
    }

    # check if email with local domain is allowed for email and sponsor sources
    my $source;
    if (defined($cgi->param('by_email'))) {
        my $email_type = pf::Authentication::Source::EmailSource->meta->get_attribute('type')->default;
        $source = $portalSession->getProfile->getSourceByType($email_type);
    }
    elsif (defined($cgi->param('by_sponsor'))) {
        my $sponsor_type = pf::Authentication::Source::SponsorEmailSource->meta->get_attribute('type')->default;
        $source = $portalSession->getProfile->getSourceByType($sponsor_type);
    }
    if ($source) {
        unless (isenabled($source->{allow_localdomain})) {
            # You should not register as a guest if you are part of the local network
            my $localdomain = $Config{'general'}{'domain'};
            if ($cgi->param('email') =~ /[@\.]$localdomain$/i) {
                return ($FALSE, $GUEST::ERROR_EMAIL_UNAUTHORIZED_AS_GUEST, [ $localdomain ]);
            }
        }
    }

    # sponsor validation in another sub to ease overrides
    if (defined($cgi->param('by_sponsor'))) {
        my ($valid_sponsor, $error_code, $error_args_ref) = pf::web::guest::validate_sponsor($portalSession);
        return ($FALSE, $error_code, $error_args_ref) if (!$valid_sponsor);
    }

    # auth accepted, save login information in session (we will use them to put the guest in the db)
    $session->param("company", $cgi->param("organization"));
    $session->param("phone", pf::web::util::validate_phone_number($cgi->param("phone")));
    $session->param("email", lc($cgi->param("email")));
    $session->param("sponsor", lc($cgi->param("sponsor_email")));
    my %exclude = (
        pid => undef,
        telephone => undef,
        email => undef,
        sponsor_email => undef,
        organization => undef,
    );
    foreach my $param ( grep { ! exists $exclude{$_} && exists $mandatory_fields{$_} } @pf::person::FIELDS) {
            my $value = $cgi->param($param);
            $session->param($param, $value) if defined $value;
    }
    # guest pid is configurable (defaults to email)
    $session->param("guest_pid", $session->param($Config{'guests_self_registration'}{'guest_pid'}));
    return ($TRUE, 0);
}

=item validate_sponsor

Performs sponsor validation.

=cut

sub validate_sponsor {
    my ($portalSession) = @_;

    my $cgi = $portalSession->getCgi();

    # validate that this email can sponsor network accesses
    my $value = &pf::authentication::match( &pf::authentication::getInternalAuthenticationSources(),
                                            { email => $cgi->param('sponsor_email') },
                                            $Actions::MARK_AS_SPONSOR );

    if (defined $value) {
        # all sponsor checks have passed
        return ($TRUE, 0);
    }

    return ($FALSE, $GUEST::ERROR_SPONSOR_NOT_ALLOWED, [ $cgi->param('sponsor_email') ] );
}

=item prepare_email_guest_activation_info

Provides basic information for the self registered guests by email template.

This is meant to be overridden in L<pf::web::custom>.

=cut

sub prepare_email_guest_activation_info {
    my ( $portalSession, %info ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # First blast at consuming portalSession object
    my $session = $portalSession->getSession();

    $info{'firstname'} = $session->param("firstname");
    $info{'lastname'} = $session->param("lastname");
    $info{'telephone'} = $session->param("phone");
    $info{'company'} = $session->param("company");
    $info{'subject'} = i18n_format("%s: Email activation required", $Config{'general'}{'domain'});
    utf8::decode($info{'subject'});
    return %info;
}

=item prepare_sponsor_guest_activation_info

Provides basic information for the self registered sponsored guests template.

This is meant to be overridden in L<pf::web::custom>.

=cut

sub prepare_sponsor_guest_activation_info {
    my ( $portalSession, %info ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # First blast at consuming portalSession object
    my $session = $portalSession->getSession();

    $info{'firstname'} = $session->param("firstname");
    $info{'lastname'} = $session->param("lastname");
    $info{'telephone'} = $session->param("phone");
    $info{'company'} = $session->param("company");
    $info{'sponsor'} = $session->param('sponsor');
    $info{'subject'} = i18n_format("%s: Guest access request", $Config{'general'}{'domain'});
    utf8::decode($info{'subject'});
    $info{'is_preregistration'} = $session->param('preregistration');

    return %info;
}

=item generate_custom_login_page

Sub to present a login form. Template is provided as a parameter.

=cut

sub generate_custom_login_page {
    my ( $portalSession, $err, $html_template ) = @_;

    $portalSession->stash->{'txt_auth_error'} = i18n($err) if (defined($err));

    # return login
    $portalSession->stash->{'username'} = encode_entities($portalSession->cgi->param("username"));
    render_template($portalSession, $html_template);
    exit;
}

=item aup

Return the Acceptable User Policy (AUP) defined in the template file
/usr/local/pf/html/captive-portal/templates/aup_text.html

=cut

sub aup {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

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
    my $logger = Log::Log4perl::get_logger('pf::web::guest');

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
    utf8::decode($subject);
    my $msg = MIME::Lite::TT->new(
        From        =>  $from,
        To          =>  $info->{'email'},
        Cc          =>  $info->{'cc'},
        Subject     =>  encode("MIME-Header", $subject),
        Template    =>  "emails-$template.txt.tt",
        TmplOptions =>  { INCLUDE_PATH => "$conf_dir/templates/" },
        TmplParams  =>  $info,
        TmplUpgrade =>  1,
    );

    $msg->send('smtp', $smtpserver, Timeout => 20)
        or $logger->warn("problem sending guest registration email");
}

sub generate_sms_confirmation_page {
    my ( $portalSession, $post_uri, $error_code, $error_args_ref ) = @_;

    $portalSession->stash->{'post_uri'} = $post_uri;

    # Error management
    if (defined($error_code) && $error_code != 0) {
        $portalSession->stash->{'txt_auth_error'} = i18n_format($GUEST::ERRORS{$error_code}, @$error_args_ref);
        utf8::decode($portalSession->stash->{'txt_auth_error'});
    }

    render_template($portalSession, 'guest/sms_confirmation.html');
    exit;
}

sub web_sms_validation {
    my ($portalSession) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # no form was submitted, assume first time
    if ($portalSession->cgi->param("pin")) {
        $logger->info("Mobile phone number validation attempt");
        if (validate_code($portalSession->cgi->param("pin"))) {
            return ( $TRUE, 0 );
        } else {
            return ( $FALSE, $GUEST::ERROR_INVALID_PIN );
        }
    } else {
        # this won't display an error
        return ( $FALSE, 0 );
    }
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
