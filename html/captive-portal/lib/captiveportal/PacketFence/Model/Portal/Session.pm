package captiveportal::PacketFence::Model::Portal::Session;
use Moose;

use pf::iplog;
use pf::config;
use constant LOOPBACK_IPV4 => '127.0.0.1';
use pf::log;
use pf::util;
use pf::config::util;
use pf::locationlog qw(locationlog_synchronize);
use NetAddr::IP;
use pf::Portal::ProfileFactory;
use File::Spec::Functions qw(catdir);
use pf::activation qw(view_by_code);
use pf::web::constants;
use URI::URL;
use URI::Escape::XS qw(uri_escape uri_unescape);
use HTML::Entities;
use List::MoreUtils qw(any);

=head1 NAME

captiveportal::PacketFence::Model::Portal::Session - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

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

has clientIp => (
    is      => 'rw',
    builder => '_build_clientIp',
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
    my $forwardedFor  = $request->{'env'}->{'HTTP_X_FORWARDED_FOR'};
    my $redirectURL;
    my $uri = $request->uri;
    my $options;
    my $mgmt_ip = $management_network->{'Tvip'} || $management_network->{'Tip'} if $management_network;

    if( $r->can('pnotes') && defined ( my $last_uri = $r->pnotes('last_uri') )) {
        $options = {
            'last_uri' => $last_uri,
            'in_uri_portal' => 1,
        };
    } elsif ( $c->action && $c->controller->isa('captiveportal::Controller::Activate::Email') && $c->action->name eq 'code' ) {
        my $code = $c->request->arguments->[0];
        my $data = view_by_code("1:".$code);
        $options = {
            'portal' => $data->{portal},
        };
    } elsif ( $forwardedFor && $mgmt_ip && ( $forwardedFor =~  $mgmt_ip) && defined($request->param('PORTAL'))) {
        $options = {
            'portal' => $request->param('PORTAL'),
        };
    }

    $model =  $self->new(
        remoteAddress => $remoteAddress,
        forwardedFor  => $forwardedFor,
        options       => $options,
        @args,
    );
    $c->session->{$class} = $model;
    return $model;
}

sub _build_clientIp {
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
            return $session_ip;
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
        return $directly_connected_ip;
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
        return $ip;
    }

    $logger->debug(
        "Remote Address is $directly_connected_ip but no further hints of client IP in HTTP Headers"

     );
    Log::Log4perl::MDC->put( 'ip', $directly_connected_ip );
    return $directly_connected_ip;
}

sub _build_clientMac {
    my ($self) = @_;
    my $clientIp = $self->clientIp;
    my $mac;
    if (defined $clientIp) {
        $clientIp = clean_ip($clientIp);
        while ( my ($network,$network_config) = each %ConfigNetworks ) {
            next unless defined $network_config->{'fake_mac_enabled'} && isenabled($network_config->{'fake_mac_enabled'});
            next if !pf::config::is_network_type_inline($network);
            my $net_addr = NetAddr::IP->new($network,$network_config->{'netmask'});
            my $ip = new NetAddr::IP::Lite $clientIp;
            if ($net_addr->contains($ip)) {
                my $fake_mac = '00:00:' . join(':', map { sprintf("%02x", $_) } split /\./, $ip->addr());
                my $gateway = $network_config->{'gateway'};
                locationlog_synchronize($gateway, $gateway, undef, $NO_PORT, $NO_VLAN, $fake_mac, $NO_VOIP, $INLINE);
                pf::iplog::open($ip->addr(), $fake_mac);
                $mac = $fake_mac;
                last;
            }
        }
        $mac = pf::iplog::ip2mac( $clientIp ) unless defined $mac;
    }
    Log::Log4perl::MDC->put('mac', $mac) if defined $mac;
    return $mac;
}

sub _build_profile {
    my ($self) = @_;
    my $options =  $self->options;
    $options->{'last_ip'} = $self->clientIp;
    return pf::Portal::ProfileFactory->instantiate( $self->clientMac, $options );
}

sub _build_dispatcherSession {
    my ($self) = @_;
    my $session = new pf::Portal::Session()->session;
    my %session_data;
    my $logger = get_logger();
    foreach my $key ($session->param) {
        my $value = $session->param($key);
        $logger->debug( sub { "Adding session parameter from dispatcher session to Catalyst session : $key : " . $value // 'undef' });
        $session_data{$key} = $value;
    }
    $logger->info("External captive portal detected !") if($session_data{is_external_portal});

    return \%session_data;
    return 1;
}

sub templateIncludePath {
    my ($self)  = @_;
    my $profile = $self->profile;
    my @paths   = ( $CAPTIVE_PORTAL{'TEMPLATE_DIR'} );
    if ( $profile->getName ne 'default' ) {
        unshift @paths,
          catdir(
            $CAPTIVE_PORTAL{'PROFILE_TEMPLATE_DIR'},
            trim_path( $profile->getTemplatePath )
          );
    }
    return \@paths;
}

__PACKAGE__->meta->make_immutable;

1;
