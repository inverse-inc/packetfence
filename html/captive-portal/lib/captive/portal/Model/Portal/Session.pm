package captive::portal::Model::Portal::Session;
use Moo;

use pf::iplog qw(ip2mac);
use pf::config;
use constant LOOPBACK_IPV4 => '127.0.0.1';
use pf::log;
use pf::Portal::ProfileFactory;

=head1 NAME

captive::portal::Model::Portal::Session - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

has [qw(clientIp clientMac profile)] => (
    is      => 'rw',
    builder => 1,
    lazy    => 1,
);

has remoteAddress => (
    is       => 'rw',
    required => 1,
);

has [qw(forwardedFor guestNodeMac)] => ( is => 'rw', );

sub ACCEPT_CONTEXT {
    my ( $self, $c ) = @_;
    my $class = ref $self || $self;
    return $c->stash->{current_model_instances}{$class}
        if exists $c->stash->{current_model_instances}{$class} && $c->stash->{current_model_instances}{$class}->isa($class);
    my $request       = $c->request;
    my $remoteAddress = $request->address;
    my $forwardedFor  = $request->header('HTTP_X_FORWARDED_FOR');
    my $model =  $self->new(
        remoteAddress => $remoteAddress,
        forwardedFor  => $forwardedFor,
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
    return ip2mac( $self->clientIp );
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
