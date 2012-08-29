package pf::web::admin;

=head1 NAME

pf::web::admin - module to handle web admin portions of the captive portal

=cut

=head1 DESCRIPTION

pf::web::admin contains the functions necessary to generate different admin-related web pages:
based on pre-defined templates: login, registration, error, etc.

It is possible to customize the behavior of this module by redefining its subs in pf::web::custom.
See F<pf::web::custom> for details.

=head1 CONFIGURATION AND ENVIRONMENT

Templates files are located under: html/admin/templates/.

=cut

use strict;
use warnings;

use HTML::Entities;
use Locale::gettext qw(bindtextdomain textdomain bind_textdomain_codeset);
use Log::Log4perl;
use POSIX qw(setlocale);
use Template;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw();
}

use pf::config;
use pf::util;
use pf::web qw(i18n ni18n i18n_format);
use pf::web::constants;
use pf::web::util;

our $VERSION = 1.00;

our $REGISTRATION_TEMPLATE = "register_guest.html";
our $REGISTRATION_CONTINUE = 10;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=item web_get_locale

Admin-related i18n setup.

=cut
sub web_get_locale {
    my ($cgi,$session) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $authorized_locale_txt = $Config{'general'}{'locale'};
    my @authorized_locale_array = split(/\s*,\s*/, $authorized_locale_txt);
    if ( defined($cgi->url_param('lang')) ) {
        $logger->info("url_param('lang') is " . $cgi->url_param('lang'));
        my $user_chosen_language = $cgi->url_param('lang');
        if (grep(/^$user_chosen_language$/, @authorized_locale_array) == 1) {
            $logger->info("setting language to user chosen language "
                 . $user_chosen_language);
            $session->param("lang", $user_chosen_language);
            return $user_chosen_language;
        }
    }
    if ( defined($session->param("lang")) ) {
        $logger->info("returning language " . $session->param("lang")
            . " from session");
        return $session->param("lang");
    }
    return $authorized_locale_array[0];
}

=item _init_i18n

=cut
sub _init_i18n {
    my ($cgi, $session) = @_;

    setlocale( POSIX::LC_MESSAGES, pf::web::admin::web_get_locale($cgi, $session) );
    bindtextdomain( "packetfence", "$conf_dir/locale" );
    textdomain("packetfence");
    bind_textdomain_codeset( "packetfence", "UTF-8" );
}

=item render_template

Cuts in the session cookies and template rendering boiler plate.

=cut
sub render_template {
    my ($cgi, $session, $template, $stash, $r) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    # so that we will get the calling sub in the logs instead of this utility sub
    local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;

    # initialize generic components to the stash
    my $default = {
        pf::web::constants::to_hash(),
        'logo' => $Config{'general'}{'logo'},
        'i18n' => \&i18n,
        'i18n_format' => \&i18n_format,
    };

    my $cookie = $cgi->cookie( CGISESSID => $session->id );
    print $cgi->header( -cookie => $cookie );

    $logger->debug("rendering template named $template");
    my $tt = Template->new({ 
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'ADMIN_TEMPLATE_DIR'}, $CAPTIVE_PORTAL{'TEMPLATE_DIR'}], 
    });
    $tt->process( $template, { %$stash, %$default } , $r ) || do {
        $logger->error($tt->error());
        return $FALSE;
    };
    return $TRUE;
}

=item generate_error_page

Error page generator for the Web Admin interface.

=cut
sub generate_error_page {
    my ( $cgi, $session, $error_msg, $r ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $logger->trace("error page requested");
    _init_i18n($cgi, $session);

    my $stash_ref = {
        txt_message => $error_msg,
        username => encode_entities( $session->param("username") ),
    };
    render_template($cgi, $session, 'error.html', $stash_ref, $r);
    exit(0);
}

=item generate_registration_page

Sub to present a guest registration form where we create the guest accounts.

=cut
sub generate_registration_page {
    my ( $cgi, $session, $err, $section ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    _init_i18n($cgi, $session);

    my $vars = {};
    # put seperately because of side effects in anonymous hashref
    $vars->{'firstname'} = $cgi->param("firstname");
    $vars->{'lastname'} = $cgi->param("lastname");
    $vars->{'company'} = $cgi->param("company");
    $vars->{'phone'} = $cgi->param("phone");
    $vars->{'email'} = lc($cgi->param("email"));
    $vars->{'address'} = $cgi->param("address");
    $vars->{'arrival_date'} = $cgi->param("arrival_date") || POSIX::strftime("%Y-%m-%d", localtime(time));
    $vars->{'notes'} = $cgi->param("notes");

    # access duration
    $vars->{'default_duration'} = $cgi->param("access_duration")
        || $Config{'guests_admin_registration'}{'default_access_duration'};

    $vars->{'duration'} = pf::web::util::get_translated_time_hash(
        [ split (/\s*,\s*/, $Config{'guests_admin_registration'}{'access_duration_choices'}) ], 
        pf::web::admin::web_get_locale($cgi, $session)
    );

    # multiple section
    $vars->{'prefix'} = $cgi->param("prefix");
    $vars->{'quantity'} = $cgi->param("quantity");
    $vars->{'columns'} = $cgi->param("columns");

    # import section
    $vars->{'delimiter'} = $cgi->param("delimiter");
    $vars->{'columns'} = $cgi->param("columns"); 

    $vars->{'username'} = $session->param("username") || "unknown";

    # showing errors
    # TODO migrate to the error constants mechanism
    if ( defined($err) ) {
        if ( $err == 1 ) {
            $vars->{'txt_error'} = i18n("Missing mandatory parameter or malformed entry.");
        } elsif ( $err == 2 ) {
            $vars->{'txt_error'} = i18n("Access duration is not of an allowed value.");
        } elsif ( $err == 3 ) {
            $vars->{'txt_error'} = i18n("Arrival date is not of expected format.");
        } elsif ( $err == 4 ) {
            $vars->{'txt_error'} = i18n("The uploaded file was corrupted. Please try again.");
        } elsif ( $err == 5 ) {
            $vars->{'txt_error'} = i18n("Can't open uploaded file.");
        } elsif ( $err == 6 ) {
            $vars->{'txt_error'} = i18n("Usernames must only contain alphanumeric characters.");
        } elsif ( $err == $REGISTRATION_CONTINUE ) {
            $vars->{'txt_error'} = i18n("Guest successfully registered. An email with the username and password has been sent.");
        } else {
            $vars->{'txt_error'} = $err;
        }
    }

    $vars->{'section'} = $section if ($section);

    render_template($cgi, $session, $pf::web::admin::REGISTRATION_TEMPLATE, $vars);
    exit;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010, 2011, 2012 Inverse inc.

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
