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
use JSON;
use Locale::gettext qw(gettext ngettext);
use Log::Log4perl;
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
use pf::constants;
use pf::config;
use pf::enforcement qw(reevaluate_access);
use pf::iplog;
use pf::node qw(node_attributes node_modify node_register node_view is_max_reg_nodes_reached);
use pf::person qw(person_nodes);
use pf::useragent;
use pf::util;
use pf::violation qw(violation_count);
use pf::web::constants;

Readonly our $LOGIN_TEMPLATE => 'login.html';
Readonly our $VIOLATION_TEMPLATE => 'remediation.html';

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

sub i18n {
    my $msgid = shift;

    return gettext($msgid);
}

sub ni18n {
    my $singular = shift;
    my $plural = shift;
    my $category = shift;

    return ngettext($singular, $plural, $category);
}

=item i18n_format

Pass message id through gettext then sprintf it.

Meant to be called from the TT templates.

=cut

sub i18n_format {
    my ($msgid, @args) = @_;

    return sprintf(gettext($msgid), @args);
}

=item render_template

Cuts in the session cookies and template rendering boiler plate.

=cut

sub render_template {
    my ($portalSession, $template, $r) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
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
        timer => $Config{'trapping'}{'redirtimer'},
        destination_url => $portalSession->getDestinationUrl(),
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_INITIAL_DELAY'},
        retry_delay => $CAPTIVE_PORTAL{'NET_DETECT_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
        auto_redirect => $Config{'captive_portal'}{'network_detection'},
    });

    render_template($portalSession, 'release.html', $r);
}


sub generate_scan_start_page {
    my ( $portalSession, $r ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $portalSession->stash({
        timer           => $Config{'scan'}{'duration'},
        txt_message     => sprintf(
            i18n("system scan in progress"),
            $Config{'scan'}{'duration'}
        ),
    });

    # Once the progress bar is over, try redirecting
    render_template($portalSession, 'scan.html', $r);
}

sub generate_login_page {
    my ( $portalSession, $err ) = @_;

    # Activate signup link if self_reg is enabled and we have at least one proper mode enabled
    if ( is_in_list($SELFREG_MODE_EMAIL, $portalSession->getProfile->getGuestModes) ||
         is_in_list($SELFREG_MODE_SMS, $portalSession->getProfile->getGuestModes) ||
         is_in_list($SELFREG_MODE_SPONSOR, $portalSession->getProfile->getGuestModes) ) {
        $portalSession->stash->{'guest_allowed'} = 1;
    } else {
        $portalSession->stash->{'guest_allowed'} = 0;
    }

    $portalSession->stash->{'txt_auth_error'} = i18n($err) if (defined($err));

    # Return login
    $portalSession->stash->{'username'} = encode_entities($portalSession->cgi->param("username"));

    # External authentication
    $portalSession->stash->{'oauth2_google'}
      = is_in_list($SELFREG_MODE_GOOGLE, $portalSession->getProfile->getGuestModes);
    $portalSession->stash->{'oauth2_facebook'}
      = is_in_list($SELFREG_MODE_FACEBOOK, $portalSession->getProfile->getGuestModes);
    $portalSession->stash->{'oauth2_github'}
      = is_in_list($SELFREG_MODE_GITHUB, $portalSession->getProfile->getGuestModes);
    $portalSession->stash->{'null_source'}
      = is_in_list($SELFREG_MODE_NULL, $portalSession->getProfile->getGuestModes);
    $portalSession->stash->{'no_username'} = _no_username($portalSession);

    render_template($portalSession, $LOGIN_TEMPLATE);
}

sub _no_username {
    my ($portalSession) = @_;
    return any {$_->type eq 'Null' && isdisabled($_->email_required)  }
        map { getAuthenticationSource($_) }
        @{$portalSession->getProfile->getSources};
}

sub generate_enabler_page {
    my ( $portalSession, $violation_id, $enable_text ) = @_;

    $portalSession->stash->{'violation_id'} = $violation_id;
    $portalSession->stash->{'enable_text'} = $enable_text;

    render_template($portalSession, 'enabler.html');
}

sub generate_redirect_page {
    my ( $portalSession ) = @_;

    render_template($portalSession, 'redirect.html');
}

=item generate_aup_standalone_page

Called when someone clicked on /aup which is the pop-up URL for mobile phones.

=cut

sub generate_aup_standalone_page {
    my ( $portalSession ) = @_;
    render_template($portalSession, 'aup.html');
}

=item generate_status_page

Called when someone accesses /status

=cut

sub generate_status_page {
    my ( $portalSession ) = @_;
    my $node_info = node_view($portalSession->getClientMac());
    if ($node_info->{'last_start_timestamp'} > 0) {
        if ($node_info->{'time_balance'} > 0) {
            # Node has a usage duration
            $node_info->{'expiration'} = $node_info->{'last_start_timestamp'} + $node_info->{'time_balance'};
            if ($node_info->{'expiration'} < time) {
                # No more access time; RADIUS accounting should have triggered a violation
                delete $node_info->{'expiration'};
                $node_info->{'time_balance'} = 0;
            }
        }
    }
    my @nodes = person_nodes($node_info->{pid});

    $portalSession->stash({
        node => $node_info,
        nodes => \@nodes,
        billing => isenabled($portalSession->getProfile->getBillingEngine),
    });

    render_template($portalSession, 'status.html');
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

=item generate_oauth2_page

Handle the redirect to the proper OAuth2 Provider

=cut

sub generate_oauth2_page {
   my ( $portalSession, $err ) = @_;
   my $logger = Log::Log4perl::get_logger(__PACKAGE__);

   # Generate the proper Client
   my $provider = $portalSession->getCgi()->url_param('provider');

   print $portalSession->cgi->redirect(oauth2_client($portalSession, $provider)->authorize);
   exit(0);
}

=item generate_oauth2_result

Handle the redirect to the proper OAuth2 Provider

=cut

sub generate_oauth2_result {
   my ( $portalSession, $provider ) = @_;
   my $logger = Log::Log4perl::get_logger(__PACKAGE__);

   my $code = $portalSession->getCgi()->url_param('code');

   $logger->debug("API CODE: $code");

   #Get the token
   my $token;

   eval {
      $token = oauth2_client($portalSession, $provider)->get_access_token($portalSession->getCgi()->url_param('code'));
   };

   if ($@) {
       $logger->warn("OAuth2: failed to receive the token from the provider: $@");
       generate_login_page( $portalSession, i18n("OAuth2 Error: Failed to get the token") );
       return 0;
   }

   my $response;

   my $type;
   # Validate the token
   if (lc($provider) eq 'facebook') {
       $type = pf::Authentication::Source::FacebookSource->meta->get_attribute('type')->default;
   } elsif (lc($provider) eq 'github') {
       $type = pf::Authentication::Source::GithubSource->meta->get_attribute('type')->default;
   } elsif (lc($provider) eq 'google') {
       $type = pf::Authentication::Source::GoogleSource->meta->get_attribute('type')->default;
   }
   my $source = $portalSession->getProfile->getSourceByType($type);
   if ($source) {
       $response = $token->get($source->{'protected_resource_url'});
       if ($response->is_success) {
           # Grab JSON content
           my $json = new JSON;
           my $json_text = $json->decode($response->content());
           if ($provider eq 'google' || $provider eq 'github' ) {
               $logger->info("OAuth2 successfull, register and release for email $json_text->{email}");
               return ($TRUE,$json_text->{email});
           } elsif ($provider eq 'facebook') {
               $logger->info("OAuth2 successfull, register and release for username $json_text->{username}");
               return ($TRUE,$json_text->{username});
           }
       } else {
           $logger->info("OAuth2: failed to validate the token, redireting to login page");
           generate_login_page( $portalSession, i18n("OAuth2 Error: Failed to validate the token, please retry") );
           return 0;
       }
   } else {
       $logger->error(sprintf("No source of type '%s' defined for profile '%s'", $type, $portalSession->getProfile->getName));
       generate_login_page( $portalSession, i18n("OAuth2 Error: Failed to get the token") );
       return 0;
   }
}

=item generate_violation_page

=cut

sub generate_violation_page {
    my ( $portalSession, $template ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my @langs = $portalSession->getLanguages();
    my $mac = $portalSession->getClientMac();
    my $paths = $portalSession->getTemplateIncludePath();

    my $node_info = node_view($mac);

    # We stash stuff we want to expose to all templates, for better
    # customizations by PacketFence administrators
    $portalSession->stash->{'dhcp_fingerprint'} = $node_info->{'dhcp_fingerprint'};
    $portalSession->stash->{'last_switch'} = $node_info->{'last_switch'};
    $portalSession->stash->{'last_port'} = $node_info->{'last_port'};
    $portalSession->stash->{'last_vlan'} =$node_info->{'last_vlan'};
    $portalSession->stash->{'last_connection_type'} = $node_info->{'last_connection_type'};
    $portalSession->stash->{'last_ssid'} =  $node_info->{'last_ssid'};
    $portalSession->stash->{'username'} = $node_info->{'pid'};

    push(@langs, ''); # default template
    foreach my $lang (@langs) {
        my $file = "violations/$template" . ($lang?".$lang":"") . ".html";
        foreach my $dir (@$paths) {
            if ( -f "$dir/$file" ) {
                $portalSession->stash->{'sub_template'} = $file;
                return render_template($portalSession, $VIOLATION_TEMPLATE);
            }
        }
    }

    $logger->error("Template $template not found");
}

=item web_node_register

This sub is meant to be redefined by pf::web::custom to fit your specific needs.
See F<pf::web::custom> for examples.

=cut

sub web_node_register {
    my ( $portalSession, $pid, %info ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # FIXME quick and hackish fix for #1505. A proper, more intrusive, API changing, fix should hit devel.
    my $mac;
    if(exists $info{'mac'} && defined $info{'mac'})  {
        $mac = $info{'mac'};
    }
    elsif (defined($portalSession->getGuestNodeMac)) {
        $mac = $portalSession->getGuestNodeMac;
    }
    else {
        $mac = $portalSession->getClientMac;
    }

    if ( is_max_reg_nodes_reached($mac, $pid, $info{'category'}) ) {
        pf::web::generate_error_page(
            $portalSession,
            i18n("You have reached the maximum number of devices you are able to register with this username.")
        );
        exit(0);
    }

    # we are good, push the registration
    return _sanitize_and_register($portalSession->session, $mac, $pid, %info);
}

sub _sanitize_and_register {
    my ( $session, $mac, $pid, %info ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    $logger->info("performing node registration MAC: $mac pid: $pid");
    node_register( $mac, $pid, %info );

     unless ( defined($session->param("do_not_deauth")) && $session->param("do_not_deauth") == $TRUE ) {
        reevaluate_access( $mac, 'manage_register' );
    }

    return $TRUE;
}

=item web_node_record_user_agent

Records User-Agent for the provided node and triggers violations.

=cut

sub web_node_record_user_agent {
    my ( $mac, $user_agent ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');

    # caching useragents, if it's the same don't bother triggering violations
    my $cached_useragent = $main::useragent_cache->get($mac);

    # Cache hit
    return if (defined($cached_useragent) && $user_agent eq $cached_useragent);

    # Caching and updating node's info
    $logger->trace("adding $mac user-agent to cache");
    $main::useragent_cache->set( $mac, $user_agent, "5 minutes");

    # Recording useragent
    $logger->info("Updating node $mac user_agent with useragent: '$user_agent'");
    node_modify($mac, ('user_agent' => $user_agent));

    # updates the node_useragent information and fires relevant violations triggers
    return pf::useragent::process_useragent($mac, $user_agent);
}

=item validate_form

    return (0, 0) for first attempt
    return (1) for valid form
    return (0, "Error string" ) on form validation problems

=cut

sub validate_form {
    my ( $portalSession ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    $logger->trace("form validation attempt");

    my $cgi = $portalSession->getCgi();
    my $no_password_needed = any {$_ eq 'null' } @{$portalSession->getProfile->getGuestModes};
    my $no_username_needed = _no_username($portalSession);

    if ( ($cgi->param("username") || $no_username_needed  ) && ( $cgi->param("password") || $no_password_needed ) ) {
        # acceptable use pocliy accepted?
        if (!defined($cgi->param("aup_signed")) || !$cgi->param("aup_signed")) {
            return ( 0 , 'You need to accept the terms before proceeding any further.' );
        }

        return (1);
    }
    return (0, 'Invalid login or password');
}

=item web_user_authenticate

    return (1, message string, source id string) for successfull authentication
    return (0, message string, undef) otherwise

=cut

sub web_user_authenticate {
    my ( $portalSession ,$username, $password) = @_;
    my $logger = Log::Log4perl::get_logger('pf::web');
    $logger->trace("authentication attempt");

    my $session = $portalSession->getSession();
    my @sources = ($portalSession->getProfile->getInternalSources, $portalSession->getProfile->getExclusiveSources);

    if (!defined($username)) {
        $username = $portalSession->cgi->param("username");
        $password = $portalSession->cgi->param("password");
    }

    # validate login and password
    my ($return, $message, $source_id) = pf::authentication::authenticate($username, $password, @sources);

    if (defined($return) && $return == 1) {
        # save login into session
        $portalSession->session->param( "username", $portalSession->cgi->param("username") );
    }
    return ($return, $message, $source_id);
}

sub generate_registration_page {
    my ( $portalSession, $pagenumber ) = @_;

    $pagenumber = 1 if (!defined($pagenumber));

    $portalSession->stash({
        reg_page_content_file => "register_$pagenumber.html",
    });

    # generate list of locales
    my $authorized_locale_txt = $Config{'general'}{'locale'};
    my @authorized_locale_array = split(/,/, $authorized_locale_txt);
    if ( scalar(@authorized_locale_array) == 1 ) {
        push @{ $portalSession->stash->{'list_locales'} },
            { name => 'locale', value => $authorized_locale_array[0] };
    } else {
        foreach my $authorized_locale (@authorized_locale_array) {
            push @{ $portalSession->stash->{'list_locales'} },
                { name => 'locale', value => $authorized_locale };
        }
    }

    if ( $pagenumber == $Config{'registration'}{'nbregpages'} ) {
        $portalSession->stash->{'button_text'} = i18n($Config{'registration'}{'button_text'});
        $portalSession->stash->{'form_action'} = '/authenticate';
    } else {
        $portalSession->stash->{'button_text'} = i18n("Next page");
        $portalSession->stash->{'form_action'} = '/authenticate?mode=next_page&page=' . ( int($pagenumber) + 1 );
    }

    render_template($portalSession, 'register.html');
}

=item generate_pending_page

Shows a page to user saying registration is pending.

=cut

sub generate_pending_page {
    my ( $portalSession ) = @_;

    $portalSession->stash({
        destination_url => $portalSession->getDestinationUrl(),
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_PENDING_INITIAL_DELAY'},
        retry_delay => $CAPTIVE_PORTAL{'NET_DETECT_PENDING_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
    });

    render_template($portalSession, 'pending.html');
}

sub generate_authorizer_page {
    my ($portalSession, %info) = @_;
    my $authorizer_name = $portalSession->getProfile()->getAuthorizer();
    my $authorizer = pf::provisioner->new($authorizer_name); 
    $portalSession->stash({
        destination_url => $portalSession->getDestinationUrl(),
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_PENDING_INITIAL_DELAY'},
        retry_delay => $CAPTIVE_PORTAL{'NET_DETECT_PENDING_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
        agent_download_uri => $authorizer->{'agent_download_uri'},
    });

    render_template($portalSession, 'authorizer.html');
    
}

sub end_authorizer_isolation {
    my ($portalSession, $mac) = @_;
    my %info;
    %info = (%info, (status=>$pf::node::STATUS_REGISTERED));
    node_modify($mac, %info);
    unless ( defined($portalSession->session->param("do_not_deauth")) && $portalSession->session->param("do_not_deauth") == $TRUE ) {
        reevaluate_access( $mac, 'manage_register' );
    }
    
    generate_release_page($portalSession); 
}

=item end_portal_session

Call after you made your changes to the user / node.
This takes care of handling violations, bouncing back to http for portal
network access detection or handling mobile provisionning.

This was done in several different locations making maintenance more difficult than it should.
It was regrouped here.

=cut

sub end_portal_session {
    my ( $portalSession ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # First blast at handling portalSession object
    my $mac             = $portalSession->getClientMac();
    my $destination_url = $portalSession->getDestinationUrl();

    # violation handling
    my $count = violation_count($mac);
    if ($count != 0) {
      print $portalSession->cgi->redirect('/captive-portal?destination_url=' . uri_escape($destination_url));
      $logger->info("more violations yet to come for $mac");
      exit(0);
    }

    if (pf::web::supports_androidconfig_provisioning($portalSession)) {
        pf::web::generate_androidconfig_provisioning_page($portalSession);
        exit(0);
    }

    # We are in a external portal set, let´s forward the device to the grant url
    if (defined($portalSession->getGrantUrl) && $portalSession->getGrantUrl ne '') {
        print $portalSession->cgi->redirect($portalSession->getGrantUrl);
        exit(0);
    }
    # we drop HTTPS so we can perform our Internet detection and avoid all sort of certificate errors
    if ($portalSession->cgi->https()) {
        print $portalSession->cgi->redirect(
            "http://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}
            .'/access?destination_url=' . uri_escape($destination_url)
        );
        exit(0);
    }

    pf::web::generate_release_page($portalSession);
    exit(0);
}

=item generate_generic_page

Present a generic page. Template and arguments provided to template passed as arguments

=cut

# TODO we could even deprecate that since people calling this here
# could stash to portalSession first.
sub generate_generic_page {
    my ( $portalSession, $template, $template_args ) = @_;

    $portalSession->stash( $template_args );
    render_template($portalSession, $template);
}

sub oauth2_client {
    my ($portalSession, $provider) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $type;
    {
        if (lc($provider) eq 'facebook') {
            $type = pf::Authentication::Source::FacebookSource->meta->get_attribute('type')->default;
        } elsif (lc($provider) eq 'github') {
            $type = pf::Authentication::Source::GithubSource->meta->get_attribute('type')->default;
        } elsif (lc($provider) eq 'google') {
            $type = pf::Authentication::Source::GoogleSource->meta->get_attribute('type')->default;
        }
    }
    if ($type) {
        my $source = $portalSession->getProfile->getSourceByType($type);
        if ($source) {
            return Net::OAuth2::Profile::WebServer->new(
                client_id => $source->{'client_id'},
                client_secret => $source->{'client_secret'},
                site => $source->{'site'},
                authorize_path => $source->{'authorize_path'},
                access_token_path => $source->{'access_token_path'},
                access_token_method => $source->{'access_token_method'},
                #access_token_param => $source->{'access_token_param'},
                scope => $source->{'scope'},
                redirect_uri => $source->{'redirect_url'} 
          );
       }
        else {
            $logger->error(sprintf("No source of type '%s' defined for profile '%s'", $type, $portalSession->getProfile->getName));
        }
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

