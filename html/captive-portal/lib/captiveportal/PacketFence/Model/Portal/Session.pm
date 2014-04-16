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

has [qw(forwardedFor guestNodeMac)] => ( is => 'rw', );

sub ACCEPT_CONTEXT {
    my ( $self, $c, @args ) = @_;
    my $class = ref $self || $self;
    return $c->stash->{current_model_instances}{$class}
        if exists $c->stash->{current_model_instances}{$class} && $c->stash->{current_model_instances}{$class}->isa($class);
    my $request       = $c->request;
    my $remoteAddress = $request->address;
    my $forwardedFor  = $request->header('HTTP_X_FORWARDED_FOR');
    my $model =  $self->new(
        remoteAddress => $remoteAddress,
        forwardedFor  => $forwardedFor,
        @args,
    );
    $c->stash->{current_model_instances}{$class} = $model;
    return $model;
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
            next if isdisabled($network_config->{'generate_fake_mac'});
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
    return pf::Portal::ProfileFactory->instantiate( $self->clientMac );
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
