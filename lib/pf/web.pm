package pf::web;

=head1 NAME

pf::web - module to generate the different web pages.

=cut

=head1 DESCRIPTION

pf::web contains the functions necessary to generate different web pages:
based on pre-defined templates: login, registration, release, error, status.

It is possible to customize the behavior of this module by redefining its subs in pf::web::custom.
See F<pf::web::custom> for details.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following template files: F<release.html>,
F<login.html>, F<enabler.html>, F<error.html>, F<status.html>,
F<register.html>.

=cut

#TODO all template destination should be variables allowing redefinitions by pf::web::custom

use strict;
use warnings;

use Date::Parse;
use File::Basename;
use HTML::Entities;
use JSON::MaybeXS;
use Locale::gettext qw(gettext ngettext);
use Readonly;
use Template;
use URI::Escape::XS qw(uri_escape uri_unescape);
use Crypt::OpenSSL::X509;
use List::MoreUtils qw(any);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw(i18n ni18n i18n_format render_template);
}

use pf::authentication;
use pf::log;
use pf::Authentication::constants;
use pf::constants;
use pf::config qw(
    %CAPTIVE_PORTAL
    %Config
);
use pf::enforcement qw(reevaluate_access);
use pf::ip4log;
use pf::node qw(node_attributes node_modify node_register node_view is_max_reg_nodes_reached);
use pf::person qw(person_nodes);
use pf::util;
use pf::violation qw(violation_count);
use pf::web::constants;
use pf::constants::realm;
use utf8;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

sub i18n {
    my $msgid = shift;

    if(ref($msgid) eq "ARRAY"){
        return i18n_format(@$msgid);
    }

    my $result = gettext($msgid);
    return $result;
}

sub ni18n {
    my $singular = shift;
    my $plural = shift;
    my $category = shift;

    my $result = ngettext($singular, $plural, $category);
    return $result;
}

=item i18n_format

Pass message id through gettext then sprintf it.

Meant to be called from the TT templates.

=cut

sub i18n_format {
    my ($msgid, @args) = @_;

    my $result = gettext($msgid);
    $result = sprintf($result, @args);
    return $result;
}

=item render_template

Cuts in the session cookies and template rendering boiler plate.

=cut

sub render_template {
    my ($portalSession, $template, $r) = @_;
    my $logger = get_logger();
    # so that we will get the calling sub in the logs instead of this utility sub
    local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;

    # add generic components to the stash
    $portalSession->stash({
        'logo' => $portalSession->getProfile->getLogo,
        'i18n' => \&i18n,
        'i18n_format' => \&i18n_format,
    });

    my @list_help_info;
    push @list_help_info, { name => i18n('IP'),  value => $portalSession->getClientIp }
        if (defined($portalSession->getClientIp));
    push @list_help_info, { name => i18n('MAC'),  value => $portalSession->getClientMac }
        if (defined($portalSession->getClientMac));
    $portalSession->stash({ list_help_info => [ @list_help_info ] });

    # lastly add user-defined stash elements
    $portalSession->stash( pf::web::stash_template_vars() );

    my $cookie = $portalSession->cgi->cookie( CGISESSION_PF => $portalSession->session->id );
    print $portalSession->cgi->header( -cookie => $cookie );

    # print custom headers if there's some
    if ( $portalSession->stash->{headers} ) {
        my @headers = $portalSession->stash->{headers};
        foreach (@headers) {
            print $portalSession->cgi->header($_);
        }
    }

    $logger->debug("rendering template named $template");

    my $tt = Template->new({
        INCLUDE_PATH => $portalSession->getTemplateIncludePath()
    });
    $tt->process( $template, $portalSession->stash, $r ) || do {
        $logger->error($tt->error());
        return $FALSE;
    };
    return $TRUE;
}

=item stash_template_vars

Sub meant to be overridden in L<pf::web::custom> to inject new variables for
consumption by the Templates.

For example, to add a helpdesk phone number variable:

  return { 'helpdesk_phone' => '514-555-1337' };

Afterwards it is available globally, in every template.

=cut

sub stash_template_vars {
    my ($portalSession, $template) = @_;
    return {};
}

sub generate_release_page {
    my ( $portalSession, $r ) = @_;

    $portalSession->stash({
        timer => $Config{'captive_portal'}{'network_redirect_delay'},
        destination_url => $portalSession->getDestinationUrl(),
        initial_delay => $Config{'captive_portal'}{'network_detection_initial_delay'},
        retry_delay => $Config{'captive_portal'}{'network_detection_retry_delay'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
        auto_redirect => $Config{'captive_portal'}{'network_detection'},
    });

    render_template($portalSession, 'release.html', $r);
}


sub generate_scan_start_page {
    my ( $portalSession, $r ) = @_;
    my $logger = get_logger();

    $portalSession->stash({
        # Hardcoded here since the scan section is gone.
        # In case this codepath is still called (pf::web::release is still called by scan in some cases)
        timer           => 60,
        txt_message     => sprintf(
            i18n("system scan in progress"),
        ),
    });

    # Once the progress bar is over, try redirecting
    render_template($portalSession, 'scan.html', $r);
}

sub generate_scan_status_page {
    my ( $portalSession, $scan_start_time, $r ) = @_;

    my $refresh_timer = 10; # page will refresh each 10 seconds

    $portalSession->stash({
        txt_message      => i18n_format('scan in progress contact support if too long', $scan_start_time),
        txt_auto_refresh => i18n_format('automatically refresh', $refresh_timer),
        refresh_timer    => $refresh_timer,
    });

    render_template($portalSession, 'scan-in-progress.html', $r);
}

sub generate_error_page {
    my ( $portalSession, $error_msg, $r ) = @_;

    $portalSession->stash->{'txt_message'} = $error_msg;

    render_template($portalSession, 'error.html', $r);
}

=item web_user_authenticate

    return (1, message string, source id string) for successfull authentication
    return (0, message string, undef) otherwise

=cut

sub web_user_authenticate {
    my ( $portalSession ,$username, $password) = @_;
    my $logger = get_logger();
    $logger->trace("authentication attempt");

    my $session = $portalSession->getSession();
    my @sources = ($portalSession->getProfile->getInternalSources, $portalSession->getProfile->getExclusiveSources);

    if (!defined($username)) {
        $username = $portalSession->cgi->param("username");
        $password = $portalSession->cgi->param("password");
    }

    # validate login and password
    my ($return, $message, $source_id, $extra) = pf::authentication::authenticate( { 'username' => $username, 'password' => $password, 'rule_class' => $Rules::AUTH, context => $pf::constants::realm::PORTAL_CONTEXT }, @sources);

    if (defined($return) && $return == 1) {
        # save login into session
        $portalSession->session->param( "username", $portalSession->cgi->param("username") );
    }
    return ($return, $message, $source_id);
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

