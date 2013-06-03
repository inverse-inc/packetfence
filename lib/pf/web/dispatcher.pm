package pf::web::dispatcher;
=head1 NAME

dispatcher.pm

=cut

use strict;
use warnings;

use Apache2::Const -compile => qw(OK DECLINED HTTP_MOVED_TEMPORARILY);
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::Response ();
use Apache2::RequestUtil ();
use Apache2::ServerRec;

use APR::Table;
use APR::URI;
use Log::Log4perl;
use Template;
use URI::Escape qw(uri_escape);

use pf::config;
use pf::util;
use pf::web::constants;

=head1 SUBROUTINES

=over

=item translate

Implementation of PerlTransHandler. Rewrite all URLs except those explicitly
allowed by the Captive portal.

For simplicity and performance this doesn't consume and leverage 
L<pf::Portal::Session>.

Reference: http://perl.apache.org/docs/2.0/user/handlers/http.html#PerlTransHandler

=cut
sub translate {
    my ($r) = shift;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    $logger->trace("hitting translator with URL: " . $r->uri);

    # be careful w/ performance here
    # Warning: we might want to revisit the /o (compile Once) if we ever want
    #          to reload Apache dynamically. pf::web::constants will need some
    #          rework also
    if ($r->uri =~ /$WEB::ALLOWED_RESOURCES/o) {
        my $s = $r->server();
        my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;
        #Because of chrome captiv portal detection we have to test if the request come from http request
        my $parsed = APR::URI->parse($r->pool,$r->headers_in->{'Referer'});
        if ($s->port eq '80' && $proto eq 'https' && $r->uri !~ /$WEB::ALLOWED_RESOURCES/o && $parsed->path !~ /$WEB::ALLOWED_RESOURCES/o) {
            #Generate a page with a refresh tag
            $r->handler('modperl');
            $r->set_handlers( PerlResponseHandler => \&html_redirect );
            return Apache2::Const::OK;
        } else {
            # DECLINED tells Apache to continue further mod_rewrite / alias processing
            return Apache2::Const::DECLINED;
        }
    }
    if ($r->uri =~ /$WEB::ALLOWED_RESOURCES_MOD_PERL/o) {
        $r->handler('modperl');
        $r->pnotes->{session_id} = $1;
        $r->set_handlers( PerlResponseHandler => ['pf::web::wispr'] );
        return Apache2::Const::OK;
    }

    # passthrough
    # if the regex is not defined, we skip, this allow us to skip an expensive Config test
    if (defined $CAPTIVE_PORTAL{'PASSTHROUGH_HOSTS_RE'} ) {
        # DECLINED tells Apache to continue further mod_rewrite / alias processing
        return Apache2::Const::DECLINED if (_matches_passthrough($r));
    }

    # fallback to a redirection: inject local redirection handler
    $r->handler('modperl');
    $r->set_handlers( PerlResponseHandler => \&handler );
    # OK tells Apache to stop further mod_rewrite / alias processing
    return Apache2::Const::OK;
}

=item _matches_passthrough

Should the current request be allowed through based on passthrough configuration?

=cut
sub _matches_passthrough {
    my ($r) = @_;

    # first match any of the hosts (allows us to quickly discard w/o looping)
    if ( $r->hostname =~ /$CAPTIVE_PORTAL{'PASSTHROUGH_HOSTS_RE'}/ ) {

        # find the right host, then match it's URI against request's URI
        foreach my $host (keys %{$CAPTIVE_PORTAL{'PASSTHROUGHS'}}) {
            if ($r->hostname =~ /^$host$/) {

                # if we got an URL match too, allow!
                # Note that we are only anchoring at the beginning of the URL
                return $TRUE
                    if ($r->uri =~ /^$CAPTIVE_PORTAL{'PASSTHROUGHS'}{$host}/);
            }
        }
    }
    return $FALSE;
}

=item handler

For simplicity and performance this doesn't consume and leverage 
L<pf::Portal::Session>.

=cut
sub handler {
    my ($r) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    $logger->trace('hitting redirector');

    my $proto;
    # Google chrome hack redirect in http
    if ($r->uri =~ /\/generate_204/) {
        $proto = $HTTP;
    } else {
        $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;
    }

    my $stash = {
        'login_url' => "$proto://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}."/captive-portal",
        'login_url_wispr' => "$proto://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}."/wispr",
    };

    # prepare custom REDIRECT response
    my $response;
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });
    $template->process( "redirection.tt", $stash, \$response ) || $logger->error($template->error());;

    # send out the redirection in a custom response
    # a custom response is required otherwise Apache take over the rendering
    # of redirects and we are unable to inject the WISPR XML
    $r->headers_out->set('Location' => $stash->{'login_url'});
    $r->content_type('text/html');
    $r->no_cache(1);
    $r->custom_response(Apache2::Const::HTTP_MOVED_TEMPORARILY, $response);
    return Apache2::Const::HTTP_MOVED_TEMPORARILY;
}

=item html_redirect

html redirection to captive portal

=cut

sub html_redirect {
    my ($r) = @_;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    $logger->trace('hitting html redirector');

    my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;
    my $stash = {
        'login_url' => "$proto://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}."/captive-portal",
    };

    # prepare custom REDIRECT response
    my $response;
    my $template = Template->new({
        INCLUDE_PATH => [$CAPTIVE_PORTAL{'TEMPLATE_DIR'}],
    });
    $template->process( "redirection.html", $stash, \$response ) || $logger->error($template->error());;
    $r->content_type('text/html');
    $r->no_cache(1);
    $r->print($response);
    return Apache2::Const::OK;
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

