package pf::web::interceptproxy;
=head1 NAME

interceptproxy.pm

=cut

use strict;
use warnings;

use Apache2::Const -compile => qw(OK DECLINED HTTP_MOVED_TEMPORARILY HTTP_MOVED_PERMANENTLY PROXYREQ_REVERSE PROXYREQ_PROXY);
use Apache2::RequestRec ();
use Apache2::Connection;
use Apache2::URI;

use APR::URI;
use Log::Log4perl;
use URI::Escape qw(uri_escape);

use pf::config;
use pf::util;
use pf::web::util;
use pf::web::constants;

use Data::Dumper;

use constant BUFF_LEN => 1024;

=head1 SUBROUTINES

=over

=item translate

Intercept proxy request to forward them to the captive portal.

=cut
sub translate {
    my ($r) = shift;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    $logger->warn("hitting interceptor with URL: " . $r->uri);
    #Fetch the captive portal URL
    my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;

    my $url = "$proto://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};
    my $parsed_portal = APR::URI->parse($r->pool, $url);
    my $parsed_request = APR::URI->parse($r->pool, $r->uri);

    #in case of a Get request to another site than the captive portal, we redirect the request to the captive portal
    if ( $parsed_request->scheme eq 'http' ) {
        if ($parsed_portal->hostname ne $parsed_request->hostname) {
            $logger->warn("REDIRECT HTTP to portal 1:".$parsed_portal->unparse);
            $r->err_headers_out->set('Location' => $parsed_portal->unparse);
            $r->content_type('text/html');
            $r->no_cache(1);
            return Apache2::Const::HTTP_MOVED_TEMPORARILY;
        }
    }
    #in case of a CONNECT request we redirect the request to the reverse proxy
     elsif ( $parsed_portal->hostname ne $parsed_request->scheme ) {
            $logger->warn("REDIRECT to reverseproxy");
            $r->parsed_uri->hostname('127.0.0.1');
            $r->parsed_uri->port('444');
            $r->uri('127.0.0.1:444');
            $r->pnotes( 'url_to_mod_proxy' => $r->uri );
            $r->handler('modperl');
            $r->set_handlers(PerlResponseHandler => []);
            $r->set_handlers(PerlFixupHandler => \&fixup);
            return Apache2::Const::OK;          
    }

    #The request match with the captive portal URL

    $logger->warn("PARSED URI:".$parsed_request->rpath);

    #If it is a Get request -> Forward to the captive portal

    if ( $parsed_request->scheme eq 'http' ) {
        my $session_cook = pf::web::util::getcookie($r->headers_in->{Cookie});
        if ($session_cook) {
            $logger->warn($session_cook);
            my (%session_id);
            session(\%session_id,$session_cook);
            $session_id{remote_ip} = $r->connection->remote_ip;
            my $uri = $parsed_portal->unparse;
            $logger->warn("REDIRECT HTTP to portal 2:".$uri);
            $r->err_headers_out->set('Location' => $uri);
            $r->content_type('text/html');
            $r->no_cache(1);
            return Apache2::Const::HTTP_MOVED_TEMPORARILY;
        } else {
            $logger->warn($r->uri);
            $r->pnotes( 'url_to_mod_proxy' => $parsed_portal->unparse.$parsed_request->rpath );
       }
    } else {

    #If it is a connect request -> forward to the reverse proxy
        $logger->warn("REMOTE2 ".$r->connection->remote_ip);
        $r->headers_in->set('X-Forwarded-For' => $r->connection->remote_ip);
        $r->parsed_uri->hostname('127.0.0.1');
        $r->parsed_uri->port('444');
        my $url = "127.0.0.1:444";
        $r->uri($url);
        $r->pnotes( 'url_to_mod_proxy' => $r->uri );
    }
    #Forward to mod_proxy
    $r->handler('modperl');
    $r->set_handlers(PerlResponseHandler => []);
    $r->set_handlers(PerlFixupHandler => \&fixup);
    return Apache2::Const::OK;
}

=item rewrite

Rewrite Location header to Packetfence captive portal.

=cut

sub rewrite {
    my $f = shift;
    my $r = $f->r;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    $logger->warn($r->content_type);
    if ($r->content_type =~ /text\/html(.*)/) {
        unless ($f->ctx) {
            my @valhead = $r->headers_out->get('Location');
            my $value = $Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};
            my $replacementheader = $r->hostname;
            my $headval;
            foreach $headval (@valhead) {
                if ($headval && $headval =~ /$value/x) {
                    $headval =~ s/$value/$replacementheader/ig;
                    $r->headers_out->unset('Location');
                    $r->headers_out->set('Location' => $headval);
                }
            }
        }
        my $ctx = $f->ctx;
        while ($f->read(my $buffer, BUFF_LEN)) {
            $ctx->{data} .= $buffer;
            $ctx->{keepalives} = $f->c->keepalives;
            $f->ctx($ctx);
        }
        # Thing we do at end
        if ($f->seen_eos) {
            # Dump datas out
            $f->print($f->ctx->{data});
        }
        return Apache2::Const::OK;
    } else {
        return Apache2::Const::DECLINED;
    }
} 


=item fixup

Last Handler and las chance to do something in the request

=cut

sub fixup {
    my $r = shift;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    #Bypass ResponseHandler and use mod_proxy
    if($r->pnotes('url_to_mod_proxy')){
        $r->set_handlers(PerlResponseHandler => undef);
        return proxy_redirect($r, $r->pnotes('url_to_mod_proxy'));
    }
}

=item proxy_redirect

Mod_proxy redirect

=cut

sub proxy_redirect {
        my ($r, $url) = @_;
        my $logger = Log::Log4perl->get_logger(__PACKAGE__);
        $logger->warn("PROXY_REDIRECT");
        $logger->warn(Dumper($r->headers_in));
        $logger->warn($url);
        $r->set_handlers(PerlResponseHandler => []);
        $r->filename("proxy:".$url);
        $r->proxyreq(2);
        $r->handler('proxy-server');
        return Apache2::Const::OK;
}

#sub dump {
#        my $r = shift;
#        my $logger = Log::Log4perl->get_logger(__PACKAGE__);
#        $logger->warn("DUMP");
#    #    $r->headers_in->set('X-Forwarded-For' => '192.168.10.15');
#        $logger->warn(Dumper($r->headers_in));
#        return Apache2::Const::OK;
#}

sub reverse {
    my $r = shift;
    my $logger = Log::Log4perl->get_logger(__PACKAGE__);
    $logger->warn("REVERSE");
    $logger->warn($r->uri);
    my $parsed_request = APR::URI->parse($r->pool, $r->uri);
    my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;

    my $url = "http://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};
    my $parsed_portal = APR::URI->parse($r->pool, $url);
    my $session_cook = pf::web::util::getcookie($r->headers_in->{Cookie});
    if ($session_cook) {
        my (%session_id);
        pf::web::util::session(\%session_id,$session_cook);
        $logger->warn("REVERSE MOD_PROXY");
        $logger->warn($session_cook);
        $r->headers_in->set('X-Forwarded-For' => $session_id{remote_ip});
        $r->headers_in->set('Host' => $Config{'general'}{'hostname'});
###     $r->add_output_filter(\&rewrite);
        my $proto = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;

        my $url = "$proto://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'};

        my $url_proxy = $url.$r->uri;
        return proxy_redirect($r, $url_proxy);
    }
    else {
        $logger->warn("REVERSE REDIRECTION");
        $logger->warn($r->uri);
        if ($r->uri =~ /$WEB::ALLOWED_RESOURCES/o) {
            my $url = "$proto://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}.$r->uri;
            return proxy_redirect($r, $url);
        } else {
            my (%session_id);
            pf::web::util::session(\%session_id);
            my $uri = $parsed_portal->unparse;
            $logger->warn("REVERSE REDIRECT HTTP to portal:".$uri);
            $r->err_headers_out->add('Set-Cookie' => "packetfence=".$session_id{_session_id}."; domain=".$parsed_portal->hostname."; path=/");
            $r->err_headers_out->set('Location' => $uri);
            $r->content_type('text/html');
            $r->no_cache(1);
            return Apache2::Const::HTTP_MOVED_TEMPORARILY;
       }
    }        
}      

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2012 Inverse inc.

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

