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
use pf::config;
use pf::util;
use pf::web::constants;
use pf::web::filter;
use pf::web::util;
use pf::proxypassthrough::constants;
use pf::Portal::Session;
use pf::web::provisioning::custom;
use pf::web::externalportal;


=head1 METHODS

=over

=item handler

Implementation of PerlTransHandler. Rewrite all URLs except those explicitly
allowed by the Captive portal.

This is the first entry point for every httpd.portal request.

Reference: http://perl.apache.org/docs/2.0/user/handlers/http.html#PerlTransHandler

=cut
sub handler {
    my $r = Apache::SSLLookup->new(shift);
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);

    $logger->debug("hitting handler with URL: " . $r->construct_url);

    # We don't want to continue in the dispatcher if the requested URI is supposed to reach the captive-portal (Catalyst)
    # - Captive-portal itself
    # - Violation pages
    # - Portal profile filters are handled by Catalyst
    # See L<pf::web::constants::CAPTIVE_PORTAL_RESOURCES>
    if ( $r->uri =~ /$WEB::CAPTIVE_PORTAL_RESOURCES/o ) {
        $logger->debug("URI " . $r->uri . " (URL: " . $r->construct_url . ") is properly handled and should now continue to the captive-portal / Catalyst");

        return Apache2::Const::DECLINED;
    }

    # Apache filtering
    # Filters out request based on different filter to avoid further processing
    # ie: Only process valid browsers user agent requests
    my $filter = new pf::web::filter;
    my $result = $filter->test($r);
    return $result if $result;

    # Proxy passthrough
    # Test if the hostname is include in the proxy_passthroughs configuration
    # In this case forward to mod_proxy
    if ( (($r->hostname.$r->uri) =~ /$PROXYPASSTHROUGH::ALLOWED_PASSTHROUGH_DOMAINS/o
            && $PROXYPASSTHROUGH::ALLOWED_PASSTHROUGH_DOMAINS ne '')
         || ($r->hostname =~ /$PROXYPASSTHROUGH::ALLOWED_PASSTHROUGH_REMEDIATION_DOMAINS/o
            && $PROXYPASSTHROUGH::ALLOWED_PASSTHROUGH_REMEDIATION_DOMAINS ne '') ) {
        my $parsed_request = APR::URI->parse($r->pool, $r->uri);
        $parsed_request->hostname($r->hostname);
        ( $r->is_https ) ? $parsed_request->scheme('https') : $parsed_request->scheme('http');
        $parsed_request->path($r->uri);

        return proxy_redirect($r, $parsed_request->unparse);
    }

    # WISPr
    # If trying to reach WISPr login page, use pf::web::wispr response handler
    if ($r->uri =~ /$WEB::ALLOWED_RESOURCES_MOD_PERL/o) {
        $r->handler('modperl');
        my $provisioning = pf::web::provisioning::custom->new();
        if ($r->uri =~ /$WEB::MOD_PERL_WISPR/o) {
            $r->pnotes->{session_id} = $1;
            $r->set_handlers( PerlResponseHandler => ['pf::web::wispr'] );
        }

        return Apache2::Const::OK;
    }
    
    $r->handler('modperl');
    $r->set_handlers( PerlResponseHandler => \&html_redirect );

    return Apache2::Const::OK;
}

=item html_redirect

Redirection to captive portal

=cut
sub html_redirect {
    my ($r) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);

    $logger->debug('hitting html_redirect');

    my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;
    my $captive_portal_domain = $Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};
    my $user_agent = $r->headers_in->{'User-Agent'};

    # Destination URL / UserAgent handling
    # We must first detect the destination URL for two distinct use cases:
    # - We want to keep it so we can redirect the user to the originally requested URL once the registration completed
    # - We need to change the protocol from HTTPS to HTTP in the case of captive portal detection mecanisms (For Apple devices, we use the useragent since they use bunch of detection URLs)
    # (Apple devices will fail to connect with a self-signed certificate, Google Chrome will fail to redirect with a self-signed certificate)
    my $destination_url = '';
    my $url = $r->construct_url;
    # First use case: We want to keep the destination URL unless it is the captive portal itself or some sort of captive portal detection URL
    if ( ($url !~ m#://\Q$captive_portal_domain\E/#) && ($url !~ /$WEB::CAPTIVE_PORTAL_DETECTION_URLS/o) && ($user_agent !~ /CaptiveNetworkSupport|iPhone|iPad/s) ) {
        $destination_url = Apache2::Util::escape_path($url,$r->pool);
        $logger->info("We set the destination URL to $destination_url for further usage");
        $r->pnotes(destination_url => $destination_url);
    }
    # Second use case: We need to change the protocol from HTTPS to HTTP
    if ( ($url =~ /$WEB::CAPTIVE_PORTAL_DETECTION_URLS/o) || ($user_agent =~ /CaptiveNetworkSupport|iPhone|iPad/s) ) {
        $proto = $HTTP;
        $logger->info("We are dealing with a device with captive portal detection capabilities. " .
            "We are using HTTP rather than HTTPS to avoid SSL certificate related errors");
    }

    my $stash = {
        'login_url' => "$proto://$captive_portal_domain/captive-portal",
        'wispr_url' => "$proto://$captive_portal_domain/wispr",
    };

    my $response = '';
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });
    $template->process("html_redirect.tt", $stash, \$response) || $logger->error($template->error());

    $r->headers_out->set('Location' => $stash->{login_url});
    $r->content_type('text/html');
    $r->no_cache(1);
    $r->custom_response(Apache2::Const::HTTP_MOVED_TEMPORARILY, $response);

    return Apache2::Const::HTTP_MOVED_TEMPORARILY;
}

=item proxy_redirect

Mod_proxy redirect

=cut
sub proxy_redirect {
    my ($r, $url) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);

    $logger->debug('hitting proxy_redirect');

    $r->set_handlers(PerlResponseHandler => []);
    $r->filename("proxy:".$url);
    $r->proxyreq(2);
    $r->handler('proxy-server');

    return Apache2::Const::OK;
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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
