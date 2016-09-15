package pf::Authentication::Source::WorldPayUSSource;

=head1 NAME

pf::Authentication::Source::WorldPayUS

=cut

=head1 DESCRIPTION

pf::Authentication::Source::WorldPayUS

=cut

use strict;
use warnings;
use Moose;
use pf::config qw($default_pid $fqdn);
use pf::constants qw($FALSE $TRUE);
use pf::Authentication::constants;
use pf::util;
use pf::log;
use HTTP::Status qw(is_success);
use WWW::Curl::Easy;
use JSON::MaybeXS;
use List::Util qw(first);
use Digest::HMAC_MD5 qw(hmac_md5_hex);
use Digest::MD5 qw(md5_hex);
use Time::Local;



use Crypt::TripleDES;

extends 'pf::Authentication::Source::BillingSource';
with 'pf::Authentication::CreateLocalAccountRole';

=head2 Attributes

=head2 class

=cut

has '+class' => (default => 'billing');

has '+type' => (default => 'WorldPayUS');

has 'base_uri' => (is => 'rw', required => 1);

has 'form_id' => (is => 'rw', required => 1);

has 'session_id' => (is => 'rw', required => 1);

has 'des_key' => (is => 'rw', required => 1);

has 'domains' => (is => 'rw', required => 1, default => '*.changeme.com');

sub cache {
    return pf::CHI->new( namespace => 'billing' );
}

sub payment_cache_key {
    my ($self, @args) = @_;
    return $self->id . "-payment-" . join(',', @args);
}

=head2 prepare_payment

Prepare the payment from authorize.net

=cut

sub prepare_payment {
    my ($self, $session, $tier, $params, $uri) = @_;
    my $hash = {};
    my $amount    = $tier->{price};
    print "amount : $amount \n";
    my $crypt = Crypt::TripleDES->new;

    my @infos = split(':', $crypt->decrypt3(pack('H*', $self->form_id), $self->des_key));
    use Data::Dumper;
    print Dumper(\@infos);
    my $template_id = $infos[2];

    my $cdata = uc(unpack('H*', $crypt->encrypt3("macaddress=".$session->{billed_mac}, $self->des_key)));

    $hash->{world_pay_checkout_url} = 
        $self->base_uri . 
        "?formid=" . uc(unpack('H*', $crypt->encrypt3(join(':', ($infos[0], $infos[1], $template_id, $amount, $self->des_key)), $self->des_key))) . 
        "&sessionid=".$self->session_id . 
        "&customdata=".$cdata;

    return $hash;
}

=head2 verify

Verify the payment from authorize.net

=cut

sub verify {
    my ($self, $session, $parameters, $uri) = @_;
    my $logger = pf::log::get_logger;
    use Data::Dumper;
    my $payment_amount = $self->cache->get($self->payment_cache_key($session->{billed_mac}));
    if(!defined($payment_amount)) {
        die "Cannot find payment. Either we didn't receive it, it expired, or you are running an active/active cluster. \n";
    }
    elsif($session->{tier}->{price} eq $payment_amount) {
        # A payment should only be validated once
        $self->cache->remove($self->payment_cache_key($session->{billed_mac}));
        return $TRUE;
    }
    else {
        die "Payment doesn't match tier ".$session->{tier}->{id}." price ".$session->{tier}->{price}."\n";
    }
}

sub handle_hook {
    my ($self, $headers, $content) = @_;
    
    my $crypt = Crypt::TripleDES->new;
    
    # Decode payload data
    my $data = { map { my @kv = split('=') ; $kv[0] => $kv[1] } split('&', $content) };
    get_logger->debug(sub { use Data::Dumper ; return "Received the following payload data : " . Dumper($data) });

    # Decode the custom data
    my $cdata_string = $crypt->decrypt3(pack('H*', $data->{customdata}), $self->des_key);
    my $cdata = { map { my @kv = split('=') ; $kv[0] => $kv[1] } split('&', $cdata_string) };
    my $mac = clean_mac($cdata->{macaddress});
    get_logger->debug(sub { use Data::Dumper ; return "Received the following custom data : " . Dumper($cdata) });
    $self->cache->set($self->payment_cache_key($mac), $data->{amount});
}

=head2 cancel

Not implemented

=cut

sub cancel {
    my ($self, $session, $parameters, $uri) = @_;
    return {};
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
