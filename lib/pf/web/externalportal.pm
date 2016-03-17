package pf::web::externalportal;

=head1 NAME

pf::web::externalportal - handle the detection of an external portal workflow

=cut

=head1 DESCRIPTION

pf::web::externalportal detect external portal workflow

=cut

use strict;
use warnings;

use Apache2::Const -compile => qw(:http);
use Apache2::Request;
use Apache2::RequestRec;
use Apache2::Connection;
use pf::log;
use UNIVERSAL::require;

use pf::config;
use pf::iplog;
use pf::locationlog qw(locationlog_view_open_mac locationlog_get_session);
use pf::Portal::Session;
use pf::util;
use pf::web::constants;
use pf::web::util;
use pf::constants;

=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::web::externalportal");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item external_captive_portal

Instantiate the switch module and use a specific captive portal

=cut

sub external_captive_portal {
    my ($self, $switchId, $req, $r, $session) = @_;
    my $logger = get_logger();

    my $switch;
    if (defined($switchId)) {
        if (pf::SwitchFactory::hasId($switchId)) {
            $switch =  pf::SwitchFactory->instantiate($switchId);
        } else {
            my $locationlog_entry = locationlog_view_open_mac($switchId);
            $switch = pf::SwitchFactory->instantiate($locationlog_entry->{'switch'});
        }

        if (defined($switch) && $switch ne '0' && $switch->supportsExternalPortal) {
            my ($client_mac,$client_ssid,$client_ip,$redirect_url,$grant_url,$status_code) = $switch->parseUrl(\$req, $r);
            my $portalSession = _setup_session($req, $client_mac, $client_ip, $redirect_url, $grant_url);
            pf::iplog::open($client_ip,$client_mac,undef) if (defined ($client_ip) && defined ($client_mac));
            return ($portalSession->session->id(), $redirect_url);
        } else {
            return 0;
        }
    }
    elsif (defined($session)) {
        my $locationlog = locationlog_get_session($session);
        my $switch = $locationlog->{switch};
        $switch = pf::SwitchFactory->instantiate($switch);
        my $mac = $locationlog->{mac};
        my $ip = defined($r->headers_in->{'X-Forwarded-For'}) ? $r->headers_in->{'X-Forwarded-For'} : $r->connection->remote_ip;
        my $portalSession = _setup_session($req, $mac, $ip, undef, undef);
        pf::iplog::open($ip,$mac,3600) if defined ($ip);
        my $redirect_url = '';
        if (defined($req->param('redirect'))) {
            $redirect_url = $req->param('redirect');
        } elsif (defined($r->headers_in->{'Referer'})) {
            $redirect_url = $r->headers_in->{'Referer'};
        }
        return ($portalSession->session->id(), $redirect_url);
    }
    else {
        return 0;
    }
}

sub _setup_session {
    my ($req, $client_mac, $client_ip, $redirect_url, $grant_url) = @_;
    use Data::Dumper; get_logger()->debug("_setup_session :".Dumper(\@_));
    my $logger = get_logger();
    my %info = (
        'client_mac' => $client_mac,
    );
    my $portalSession = pf::Portal::Session->new(%info);
    $portalSession->setClientIp($client_ip) if (defined($client_ip));
    $portalSession->setDestinationUrl($redirect_url) if (defined($redirect_url));
    $portalSession->setGrantUrl($grant_url) if (defined($grant_url));
    $portalSession->session->param('is_external_portal', $TRUE);
    if(defined($req)){
        foreach my $key (keys %{$req->param}) {
            $logger->debug("Adding additionnal session parameter for url detected : $key : ".$req->param($key));
            $portalSession->session->param("ecwp-original-param-$key", $req->param($key));
        }
    }
    return $portalSession;

}

=item handle

handle the detection of the external portal

=cut

sub handle {
    my ($self,$r) = @_;
    my $req = Apache2::Request->new($r);
    my $logger = get_logger();
    my $is_external_portal;
    my $url = $r->uri;

    if ($url =~ /$WEB::EXTERNAL_PORTAL_URL/o) {
        $logger->debug("The URL is detected as an external captive portal URL");
        $url =~ s/\///g;
        my $type = "pf::Switch::".$url;
        if ( !(eval "$type->require()" ) ) {
            $logger->error("Can not load perl module for switch type: $type. "
                . "Either the type is unknown or the perl module has compilation errors. "
                . "Read the following message for details: $@");
        }
        my $switchId = $type->parseSwitchIdFromRequest(\$req);
        $logger->debug("Found switchId : $switchId");

        my ($cgi_session_id, $redirect_url) = $self->external_captive_portal($switchId,$req,$r,undef);
        if ($cgi_session_id ne '0') {
            return ($cgi_session_id, $redirect_url);
        }
    }

    foreach my $param ($req->param) {
        if ($param =~ /$WEB::EXTERNAL_PORTAL_PARAM/o) {
            my $value;
            $value = clean_mac($req->param($param)) if valid_mac($req->param($param));
            $value = $req->param($param) if  valid_ip($req->param($param));
            if (defined($value)) {
                my ($cgi_session_id, $redirect_url) = $self->external_captive_portal($value,$req,$r,undef);
                if ($cgi_session_id ne '0') {
                    return ($cgi_session_id, $redirect_url);
                }
            }
        }
    }

    # Try to fetch the parameters in the session
    if ($r->uri =~ /$WEB::EXTERNAL_PORTAL_PARAM/o) {
        my ($cgi_session_id, $redirect_url) = $self->external_captive_portal(undef,$req,$r,$1);
            if ($cgi_session_id ne '0') {
                return ($cgi_session_id, $redirect_url);
            }
    }
    return 0;
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
