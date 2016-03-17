package pf::web::dispatcher;
=head1 NAME

dispatcher.pm

=cut

use strict;
use warnings;

use Apache2::Const -compile => qw(OK DECLINED HTTP_MOVED_TEMPORARILY);
use Apache2::Request;
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::Response ();
use Apache2::RequestUtil ();
use Apache2::ServerRec;
use Apache2::URI ();
use Apache2::Util ();

use APR::Table;
use APR::URI;
use Template;
use URI::Escape::XS qw(uri_escape);
BEGIN {
    use pf::log service => 'httpd.portal';
}

use pf::log;
use pf::config;
use pf::util;
use pf::web::constants;
use pf::web::filter;
use pf::web::util;
use pf::proxypassthrough::constants;
use pf::Portal::Session;
use pf::web::externalportal;
use pf::inline;

=head1 SUBROUTINES

=over

=item handler

Implementation of PerlTransHandler. Rewrite all URLs except those explicitly
allowed by the Captive portal.

This is the first entry point for every httpd.portal request.

Reference: http://perl.apache.org/docs/2.0/user/handlers/http.html#PerlTransHandler

=cut

sub handler {
    my $r = Apache::SSLLookup->new(shift);
    my $logger = get_logger();

    my $hostname = $r->hostname || $r->connection->local_ip();
    my $uri = $r->uri;
    my $url = $r->construct_url;
    my $user_agent = $r->headers_in->{'User-Agent'};

    $logger->debug("hitting handler with URI '$uri' (URL: $url)");

    # Apache filtering
    # Filters out requests based on different filters to avoid further/unnecessary processing
    # ie.: Only process valid browsers user agent requests
    my $filter = new pf::web::filter;
    my $result = $filter->test($r);
    return $result if $result;

    # Proxy passthrough
    if ( ($hostname =~ /$PROXYPASSTHROUGH::ALLOWED_PASSTHROUGH_DOMAINS/o && $PROXYPASSTHROUGH::ALLOWED_PASSTHROUGH_DOMAINS ne '')
      || ($hostname =~ /$PROXYPASSTHROUGH::ALLOWED_PASSTHROUGH_REMEDIATION_DOMAINS/o && $PROXYPASSTHROUGH::ALLOWED_PASSTHROUGH_REMEDIATION_DOMAINS ne '') ) {
        $logger->info("URI '$uri' (URL: $url) match proxy passthrough configuration.");
        return proxy_redirect($r);
    }

    # Captive-portal detection mecanism
    # Ability to bypass captive-portal detection mecanism
    my $captive_portal_detection_mecanism_urls = pf::web::util::build_captive_portal_detection_mecanisms_regex;
    if ( ($url =~ /$captive_portal_detection_mecanism_urls/o || $user_agent =~ /CaptiveNetworkSupport/s) && isenabled($Config{'captive_portal'}{'detection_mecanism_bypass'}) ) {
        $logger->info("Dealing with a endpoint / browser with captive-portal detection capabilities while having captive-portal detection mecanism bypass enabled. Proxying");
        return proxy_redirect($r);
    }
    # Enforce HTTP instead of HTTPS when dealing with captive-portal detection mecanism and having a self-signed SSL certificate
    elsif ( ($url =~ /$captive_portal_detection_mecanism_urls/o || $user_agent =~ /CaptiveNetworkSupport/s)
      && isenabled($Config{'captive_portal'}{'secure_redirect'}) && pf::web::util::is_certificate_self_signed ) {
        $logger->info("Dealing with a endpoint / browser with captive-portal detection capabilities while having a self-signed SSL certificate. Using HTTP instead of HTTPS");
        return html_redirect($r, { secure => $FALSE });
    }

    # Captive-portal static resources
    # We don't want to continue in dispatcher in this case and we simply serve it
    # - Images
    # - Javascript scripts
    # - ...
    # See L<pf::web::constants::CAPTIVE_PORTAL_STATIC_RESOURCES>
    if ( $uri =~ /$WEB::CAPTIVE_PORTAL_STATIC_RESOURCES/o ) {
        $logger->debug("URI '$uri' (URL: $url) is a captive-portal static resource");
        $r->set_handlers( PerlResponseHandler => ['pf::web::static'] );
        return Apache2::Const::DECLINED;
    }

    # Captive-portal resource | WISPr
    if ( $uri =~ /$WEB::URL_WISPR/o ) {
        $logger->debug("URI '$uri' (URL: $url) is a WISPr request");
        $r->handler('modperl');
        $r->set_handlers( PerlResponseHandler => ['pf::web::wispr'] );
        return Apache2::Const::OK;
    }

    # Billing hooks
    if ($r->uri =~ m#/hook/billing#) {
        $logger->trace("Found the hook");
        $r->handler('modperl');
        $r->set_handlers( PerlResponseHandler => ['pf::web::billinghook'] );
        return Apache2::Const::DECLINED;
    }

    # Captive-portal resources
    # We don't want to continue in the dispatcher if the requested URI is supposed to reach the captive-portal (Catalyst)
    # - Captive-portal itself
    # - Violation pages
    # - Portal profile filters are handled by Catalyst
    # See L<pf::web::constants::CAPTIVE_PORTAL_RESOURCES>
    if ( $uri =~ /$WEB::CAPTIVE_PORTAL_RESOURCES/o ) {
        $logger->debug("URI '$uri' (URL: $url) is properly handled and should now continue to the captive-portal / Catalyst");
        return Apache2::Const::DECLINED;
    }

    # Portal-profile filters
    # TODO: Migrate to Catalyst
    if ( defined($WEB::ALLOWED_RESOURCES_PROFILE_FILTER) && $uri =~ /$WEB::ALLOWED_RESOURCES_PROFILE_FILTER/o ) {
        $logger->info("Matched profile uri filter for $uri");
        #Send the current URI to catalyst with the pnotes
        $r->pnotes(last_uri => $uri);
        return Apache2::Const::DECLINED;
    }

    # Redirect everything else to the captive-portal URL
    $r->handler('modperl');
    $r->set_handlers( PerlResponseHandler => \&html_redirect );
    return Apache2::Const::OK;
}

=item html_redirect

=cut

sub html_redirect {
    my ($r, $params) = @_;
    my $logger = get_logger();

    $logger->debug("hitting html_redirect with URI '" . $r->uri . "' (URL: " . $r->construct_url . ")");
    $logger->debug(sub { "'html_redirect' called with the following parameters: " . join(", ", map { "$_ => $params->{$_}" } keys %$params) }) if defined($params);

    my $proto;
    if ( defined($params->{'secure'}) && $params->{'secure'} ne "" ) {
        $proto = isenabled($params->{'secure'}) ? $HTTPS : $HTTP;
    } else {
        $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;
    }

    my $captive_portal_domain = $Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};
    my $ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;
    $ip = new NetAddr::IP::Lite clean_ip($ip);
    my $user_agent = $r->headers_in->{'User-Agent'};

    # Destination URL handling
    # We first must detect the destination URL for different use cases:
    # - We want to keep it so we can redirect the user to the originally requested URL once the registration completed
    # - We want to be able to detect a potential captive-portal detection mecanism to disable HTTPS since it may cause issues
    my $destination_url = "";
    my $url = $r->construct_url;

    # Keeping destination URL unless it is the captive-portal itself or some sort of captive-portal detection URLs
    my $captive_portal_detection_mecanism_urls = pf::web::util::build_captive_portal_detection_mecanisms_regex;
    if ( ($url !~ m#://\Q$captive_portal_domain\E/#) && ($url !~ /$captive_portal_detection_mecanism_urls/o) && ($user_agent !~ /CaptiveNetworkSupport/s) ) {
        $destination_url = Apache2::Util::escape_path($url,$r->pool);
        $logger->debug("We set the destination URL to $destination_url for further usage");
        $r->pnotes(destination_url => $destination_url);
    }

    # Configuring redirect URLs for both the portal and the WISPr(need to be part of the header in case of a WISPr client)
    my $portal_url = APR::URI->parse($r->pool,"$proto://".${captive_portal_domain}."/captive-portal");
    $portal_url->query("destination_url=$destination_url&".$r->args);
    my $wispr_url = APR::URI->parse($r->pool,"$proto://".${captive_portal_domain}."/wispr");
    $wispr_url->query($r->args);

    # External captive-portal / Webauth handling
    # In the case of an external captive-portal, we want to use a different URL (the hostname to which the network equipment send the request, which is PacketFence but maybe not the configured hostname in pf.conf)
    # We also need to keep track of the CGI session by setting a cookie
    my $inline = pf::inline->new();
    if (!($inline->isInlineIP($ip))) {
        my $external_portal = pf::web::externalportal->new;
        my ( $cgi_session_id, $external_portal_destination_url ) = $external_portal->handle($r);
        if ( $cgi_session_id ) {
            $logger->debug("We are dealing with an external captive-portal / webauth request. Adjusting the redirect URL accordingly");
            $r->err_headers_out->add('Set-Cookie' => "CGISESSION_PF=".  $cgi_session_id . "; path=/");
            $destination_url = $external_portal_destination_url if ( defined($external_portal_destination_url) );

            # Re-Configuring redirect URLs for both the portal and the WISPr(need to be part of the header in case of a WISPr client)
            $portal_url = APR::URI->parse($r->pool,"$proto://".$r->hostname."/captive-portal");
            $portal_url->query("destination_url=$destination_url&".$r->args);
            $wispr_url = APR::URI->parse($r->pool,"$proto://".$r->hostname."/wispr");
            $wispr_url->query($r->args);
        }
    }

    my $stash = {
        'portal_url'    => $portal_url->unparse(),
        'wispr_url'     => $wispr_url->unparse(),
        'is_wispr_redirection_enabled'  => isenabled($Config{'captive_portal'}{'wispr_redirection'}) ? $TRUE : $FALSE,
    };

    my $response = '';
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });
    $template->process("redirect.tt", $stash, \$response) || $logger->error($template->error());

    $r->headers_out->set('Location' => $stash->{portal_url});
    $r->content_type('text/html');
    $r->err_headers_out->add('Cache-Control' => "no-cache, no-store, must-revalidate");
    $r->err_headers_out->add('Pragma' => "no-cache");
    $r->err_headers_out->add('Expire' => '10');
    $r->custom_response(Apache2::Const::HTTP_MOVED_TEMPORARILY, $response);

    return Apache2::Const::HTTP_MOVED_TEMPORARILY;
}

=item proxy_redirect

=cut

sub proxy_redirect {
    my ($r) = @_;
    my $logger = get_logger();

    $logger->debug("hitting proxy_redirect with URI '" . $r->uri . "' (URL: " . $r->construct_url . ")");

    my $parsed_request = APR::URI->parse($r->pool, $r->uri);
    $parsed_request->hostname($r->hostname);
    ( $r->is_https ) ? $parsed_request->scheme('https') : $parsed_request->scheme('http');
    $parsed_request->path($r->uri);
    $r->set_handlers(PerlResponseHandler => []);
    $r->filename("proxy:" . $parsed_request->unparse);
    $r->proxyreq(2);
    $r->handler('proxy-server');

    return Apache2::Const::OK;
}

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
