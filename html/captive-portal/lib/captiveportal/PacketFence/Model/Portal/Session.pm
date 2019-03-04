package captiveportal::PacketFence::Model::Portal::Session;
use Moose;

use pf::util::IP;
use pf::ip4log;
use pf::ip6log;
use pf::config qw(
    $management_network
    %CAPTIVE_PORTAL
    %ConfigNetworks
    $NO_PORT
    $NO_VLAN
    $NO_VOIP
    $INLINE
);
use constant LOOPBACK_IPV4 => '127.0.0.1';
use pf::log;
use pf::util;
use pf::config::util;
use pf::locationlog qw(locationlog_synchronize);
use NetAddr::IP;
use pf::Connection::ProfileFactory;
use File::Spec::Functions qw(catdir);
use pf::activation qw(view_by_code);
use pf::web::constants;
use URI::URL;
use URI::Escape::XS qw(uri_escape uri_unescape);
use HTML::Entities;
use List::MoreUtils qw(any);
use pf::constants::Portal::Session qw($DUMMY_MAC);
use pf::dal::tenant;

=head1 NAME

captiveportal::PacketFence::Model::Portal::Session - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

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

has clientIP => (
    is      => 'rw',
    builder => '_build_clientIP',
    lazy    => 1,
);

has clientMac => (
    is      => 'rw',
    builder => '_build_clientMac',
    lazy    => 1,
);

has profile => (
    is      => 'rw',
    builder => '_build_profile',
    lazy    => 1,
);

has remoteAddress => (
    is       => 'rw',
    required => 1,
);

has options => (
    is       => 'rw',
    default  => sub { {} },
);

has redirectURL => (
    is       => 'rw',
);

has dispatcherSession => (
    is      => 'rw',
    builder => '_build_dispatcherSession',
    lazy => 1,
);

has [qw(forwardedFor guestNodeMac)] => ( is => 'rw', );

sub ACCEPT_CONTEXT {
    my ( $self, $c, @args ) = @_;
    my $class = ref $self || $self;
    my $previous_model = $c->session->{$class};
    my $request       = $c->request;
    my $r = $request->{'env'}->{'psgi.input'};
    return $previous_model if(defined($previous_model) && $previous_model->{options}->{in_uri_portal} && !($r->can('pnotes') && defined ($r->pnotes('last_uri') ) ) );
    my $model;
    my $remoteAddress = $request->address;
    my $forwardedFor  = $request->{'env'}->{'HTTP_X_FORWARDED_FOR_PACKETFENCE'} ||  $request->{'env'}->{'HTTP_X_FORWARDED_FOR'};
    my $redirectURL;
    my $uri = $request->uri;
    my $options;
    my $mgmt_ip = $management_network->{'Tvip'} || $management_network->{'Tip'} if $management_network;

    $self->setupTenant($c);

    if( $r->can('pnotes') && defined ( my $last_uri = $r->pnotes('last_uri') )) {
        $options = {
            'last_uri' => $last_uri,
            'in_uri_portal' => 1,
        };
    } elsif ( $c->action && $c->controller->isa('captiveportal::Controller::Activate::Email') && $c->action->name eq 'code' ) {
        my ($type, $code) = @{$c->request->arguments}[0,1];
        my $data = view_by_code($type, $code);
        $options = {
            'portal' => $data->{portal},
        };
        pf::dal->set_tenant($data->{tenant_id});
    } elsif ( $forwardedFor && ( $forwardedFor =~  '127.0.0.1') ) {
        if (defined($request->param('PORTAL'))) {
            $options = {
                'portal' => $request->param('PORTAL'),
            };
        } elsif (defined(my $cookie = $request->cookie("PF_PORTAL"))) {
            $options = {
                'portal' => $cookie->value,
            };
        }
    }
    $options->{fqdn} = $request->uri->host;

    $model =  $self->new(
        remoteAddress => $remoteAddress,
        forwardedFor  => $forwardedFor,
        options       => $options,
        @args,
    );
    $c->session->{$class} = $model;
    return $model;
}

sub _build_clientIP {
    my ($self) = @_;
    my $logger = get_logger();

    # we fetch CGI's remote address
    # if user is behind a proxy it's not sufficient since we'll get the proxy's IP
    my $directly_connected_ip = $self->remoteAddress;

    # Handle NATed web authentication clients
    if($self->dispatcherSession->{is_external_portal}){
        my $session_ip = $self->dispatcherSession->{_client_ip};
        if(defined($session_ip)){
            $logger->info("Detected external portal client. Using the IP $session_ip address in it's session.");
            Log::Log4perl::MDC->put( 'ip', $session_ip );
            return pf::util::IP::detect($session_ip);
        }
        else{
            $logger->error("Tried to compute the IP address from external portal session but found an undefined value");
        }
    }

    # every source IP in this table are considered to be from a proxied source
    my %proxied_lookup =
      %{ $CAPTIVE_PORTAL{'loadbalancers_ip'} };    #load balancers first
    $proxied_lookup{LOOPBACK_IPV4} = 1;            # loopback (proxy-bypass)
         # adding virtual IP if one is present (proxy-bypass w/ high-avail.)
    $proxied_lookup{ $management_network->tag('vip') } = 1
      if ( $management_network && $management_network->tag('vip') );

    # if this is NOT from one of the expected proxy IPs return the IP
    if ( ( !$proxied_lookup{$directly_connected_ip} )
        && !( $directly_connected_ip ne '127.0.0.1' ) ) {
        Log::Log4perl::MDC->put( 'ip', $directly_connected_ip );
        return pf::util::IP::detect($directly_connected_ip);
    }

    my $forwarded_for = $self->forwardedFor;

    # behind a proxy?
    if ( defined($forwarded_for) ) {
        my @proxied_ip = split( ',', $forwarded_for );
        my $ip = $proxied_ip[0];
        $logger->debug(
            "Remote Address is $directly_connected_ip. Client is behind proxy? "
              . "Returning: $ip according to HTTP Headers" );
        Log::Log4perl::MDC->put( 'ip', $ip);
        return pf::util::IP::detect($ip);
    }

    $logger->debug(
        "Remote Address is $directly_connected_ip but no further hints of client IP in HTTP Headers"

     );
    Log::Log4perl::MDC->put( 'ip', $directly_connected_ip );
    return pf::util::IP::detect($directly_connected_ip);
}

sub _build_clientMac {
    my ($self) = @_;
    my $clientIP = $self->clientIP;
    my $mac;
    if (defined $clientIP) {
        while ( my ($network,$network_config) = each %ConfigNetworks ) {
            next unless defined $network_config->{'fake_mac_enabled'} && isenabled($network_config->{'fake_mac_enabled'});
            next if !pf::config::is_network_type_inline($network);
            my $net_addr = NetAddr::IP->new($network,$network_config->{'netmask'});
            my $ip = new NetAddr::IP::Lite $clientIP->normalizedIP;
            if ($net_addr->contains($ip)) {
                my $fake_mac = '00:00:' . join(':', map { sprintf("%02x", $_) } split /\./, $ip->addr());
                my $gateway = $network_config->{'gateway'};
                locationlog_synchronize($gateway, $gateway, undef, $NO_PORT, $NO_VLAN, $fake_mac, $NO_VOIP, $INLINE);
                if ( $clientIP->type eq $pf::IPv6::TYPE ) {
                    pf::ip6log::open($clientIP->normalizedIP, $fake_mac);
                } else {
                    pf::ip4log::open($clientIP->normalizedIP, $fake_mac);
                }
                $mac = $fake_mac;
                last;
            }
        }
        if ( $clientIP->type eq $pf::IPv6::TYPE ) {
            $mac = pf::ip6log::ip2mac( $clientIP->normalizedIP ) unless defined $mac;
        } else {
            $mac = pf::ip4log::ip2mac( $clientIP->normalizedIP ) unless defined $mac;
        }
    }

    Log::Log4perl::MDC->put('mac', $mac) if defined $mac;
    return $mac;
}

sub _build_profile {
    my ($self) = @_;
    my $options =  $self->options;
    $options->{'last_ip'} = $self->clientIP->normalizedIP;
    return pf::Connection::ProfileFactory->instantiate( $self->clientMac, $options );
}

sub _build_dispatcherSession {
    my ($self) = @_;
    my $logger = get_logger();

    # Restore with a dummy MAC since we don't care about what contains the session if it can't be restored from the session ID
    my $portal_session = new pf::Portal::Session(client_mac => $DUMMY_MAC);

    if($portal_session->{_dummy_session}) {
        $logger->debug("Ignoring dispatcher session as it wasn't restored from a valid session ID");
        return {};
    }

    my $session = $portal_session->session;

    my %session_data;
    foreach my $key ($session->param) {
        my $value = $session->param($key);
        $logger->debug( sub { "Adding session parameter from dispatcher session to Catalyst session : $key : " . ($value // 'undef') });
        $session_data{$key} = $value;
    }
    $logger->info("External captive portal detected !") if($session_data{is_external_portal});

    return \%session_data;
    return 1;
}

sub templateIncludePath {
    my ($self)  = @_;
    my $profile = $self->profile;
    return $profile->{_template_paths};
}

=head2 setupTenant

Setup the current tenant

=cut

sub setupTenant {
    my ($self, $c) = @_;
    my $hostname = $c->request->uri->host;
    $c->log->trace("Trying to find tenant for hostname $hostname");
    if(my $tenant = pf::dal::tenant->search(-where => { portal_domain_name => $hostname })->next()) {
        $c->log->debug("Found tenant for portal domain name $hostname");
        pf::dal->set_tenant($tenant->id);
    }
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
