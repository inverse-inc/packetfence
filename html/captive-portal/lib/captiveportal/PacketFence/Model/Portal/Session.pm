package captiveportal::PacketFence::Model::Portal::Session;
use Moose;

use pf::iplog qw(ip2mac);
use pf::config;
use constant LOOPBACK_IPV4 => '127.0.0.1';
use pf::log;
use pf::util;
use pf::locationlog qw(locationlog_synchronize);
use NetAddr::IP;
use pf::iplog qw(iplog_open);
use pf::Portal::ProfileFactory;
use File::Spec::Functions qw(catdir);
use pf::activation qw(view_by_code);
use pf::web::constants;
use URI::Escape::XS qw(uri_escape uri_unescape);
use HTML::Entities;

=head1 NAME

captiveportal::PacketFence::Model::Portal::Session - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

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

has destination_url => (
    is       => 'rw',
);

has [qw(forwardedFor guestNodeMac)] => ( is => 'rw', );

sub ACCEPT_CONTEXT {
    my ( $self, $c, @args ) = @_;
    my $class = ref $self || $self;
    my $model = $c->session->{$class};
    my $request       = $c->request;
    my $r = $request->{'env'}->{'psgi.input'};
    return $model if (defined($model) && $r->isa('Apache2::Request') && !($r->pnotes('last_uri')) );
    my $remoteAddress = $request->address;
    my $forwardedFor  = $request->header('HTTP_X_FORWARDED_FOR');
    my $redirectURL;
    my $uri = $request->uri;
    my $options;
    my $destination_url;
    $destination_url = $request->param('destination_url') if defined($request->param('destination_url'));

    my $code = $1 if ($r->uri =~ /$WEB::URL_EMAIL_ACTIVATION_LINK\/(.*)/);
    if( $r->isa('Apache2::Request') &&  defined ( my $last_uri = $r->pnotes('last_uri') )) {
        $options = {
            'last_uri' => $last_uri,
        };
    } elsif (defined($code)) {
        my $data = view_by_code("1:".$code);
        $options = {
            'portal' => $data->{portal},
        };
    }

    $model =  $self->new(
        remoteAddress => $remoteAddress,
        forwardedFor  => $forwardedFor,
        options       => $options,
        destination_url => $destination_url,
        @args,
    );
    $c->session->{$class} = $model;
    return $model;
}

sub _build_destinationUrl {
    my ($self) = @_;

    # Return portal profile's redirection URL if destination_url is not set or if redirection URL is forced
    if (!defined($self->destination_url) || isenabled($self->profile->forceRedirectURL)) {
        return $self->profile->getRedirectURL;
    }

    # Respect the user's initial destination URL
    return decode_entities(uri_unescape($self->destination_url));
}

sub _build_clientIp {
    my ($self) = @_;
    my $logger = get_logger;

    # we fetch CGI's remote address
    # if user is behind a proxy it's not sufficient since we'll get the proxy's IP
    my $directly_connected_ip = $self->remoteAddress;

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
        return $directly_connected_ip;
    }

    my $forwarded_for = $self->forwardedFor;

    # behind a proxy?
    if ( defined($forwarded_for) ) {
        my @proxied_ip = split( ',', $forwarded_for );
        $logger->debug(
            "Remote Address is $directly_connected_ip. Client is behind proxy? "
              . "Returning: $proxied_ip[0] according to HTTP Headers" );
        return $proxied_ip[0];
    }

    $logger->debug(
        "Remote Address is $directly_connected_ip but no further hints of client IP in HTTP Headers"
    );
    return $directly_connected_ip;
}

sub _build_clientMac {
    my ($self) = @_;
    my $clientIp = $self->clientIp;
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
                iplog_open($fake_mac, $ip->addr());
                return $fake_mac;
            }
        }
        return ip2mac( $clientIp );
    }
    return undef;
}

sub _build_profile {
    my ($self) = @_;
    return pf::Portal::ProfileFactory->instantiate( $self->clientMac, $self->options);
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
