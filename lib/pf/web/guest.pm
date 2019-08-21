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
use pf::config qw(
    %Config
    $fqdn
    %CAPTIVE_PORTAL
);
use pf::file_paths qw($html_dir);
use pf::password;
use pf::util;
use pf::config::util qw();
use pf::web qw(i18n ni18n i18n_format render_template);
use pf::web::constants;
use pf::web::guest::constants;
use pf::web::util;
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::person;

our $VERSION = 1.41;

our $SPONSOR_CONFIRMED_TEMPLATE = "activation/sponsor_accepted.html";
our $SPONSOR_LOGIN_TEMPLATE = "activation/sponsor_login.html";
our $SPONSOR_SET_ACCESS_DURATIONS_TEMPLATE = "activation/sponsor_set_access_durations.html";

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
Readonly our $TEMPLATE_EMAIL_PASSWORD_OF_THE_DAY => 'guest_password_of_the_day';

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
    utf8::decode($subject);
    my %data = %$info;
    $data{from} ||= $pf::web::guest::EMAIL_FROM;
    return pf::config::util::send_email($template, $info->{email}, $subject, \%data);
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
