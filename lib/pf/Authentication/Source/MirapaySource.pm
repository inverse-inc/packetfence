package pf::Authentication::Source::MirapaySource;
=head1 NAME

pf::Authentication::Source::MirapaySource

=cut

=head1 DESCRIPTION

pf::Authentication::Source::MirapaySource

=cut

use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use URI::Escape::XS qw(uri_escape uri_unescape);
use Moose;
use pf::log;
use pf::config qw($default_pid);
use pf::constants qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::util;
use List::Util qw(pairmap);
use Readonly;

extends 'pf::Authentication::Source::BillingSource';
with 'pf::Authentication::CreateLocalAccountRole';

Readonly::Scalar our $MIRAPAY_ACTION_CODE_APPROVED => 'A';
Readonly::Scalar our $MIRAPAY_ACTION_CODE_DECLINED => 'D';

=head2 Attributes

=head2 class

=cut

has '+class' => (default => 'billing');

has '+type' => (default => 'Mirapay');

has base_url => (
    is => 'rw',
    default => "https://staging.eigendev.com/MiraSecure/GetToken.php",
);

has shared_secret => (
    is => 'rw',
    required => 1,
);

has merchant_id => (
    is => 'rw',
    required => 1,
);

=head2 prepare_payment

Prepare the payment from mirapay

=cut

sub prepare_payment {
    my ($self, $session, $tier, $params, $uri) = @_;
    my $hash = {
        mirapay_url => $self->make_mirapay_url($params, $tier),
    };
    return $hash;
}

=head2 verify

Verify the payment from mirapay

=cut

sub verify {
    my ($self, $session, $parameters, $uri) = @_;
    my $logger = get_logger();
    $logger->trace( sub {"Verifing $uri for source ". $self->id});
    my $action_code = $parameters->{'ActionCode'};
    if($MIRAPAY_ACTION_CODE_APPROVED ne $action_code) {
        die "Transaction declined";
    }
    unless ($self->verify_mkey($uri->query)) {
        die "Invalid transaction provided";
    }
    return {};
}

=head2 cancel

Not implemented

=cut

sub cancel {
    my ($self, $session, $parameters, $uri) = @_;
    return {};
}

=head2 calc_mkey

Calaulate the mkey from parameters given

=cut

sub calc_mkey {
    my ($self, @params) = @_;
    sha256_hex(@params, $self->shared_secret);
}

sub verify_mkey {
    my ($self, $query) = @_;
    my $logger = get_logger;
    my @params;
    for my $item (split ('&',$query)) {
        my ($name,$value) = split ('=',$item);
        push @params, uri_unescape($name),uri_unescape($value // '');
    }
    my $mkey = pop @params;
    my $name = pop @params;
    if ($name ne 'MKEY') {
         $logger->error("Invalid query the last query parameter is not MKEY $query");
         return 0;
    }
    my $test_key = $self->calc_mkey(@params);
    return $test_key eq $mkey ;
}

=head2 make_mirapay_url

Make Mirapay URL

=cut

sub make_mirapay_url {
    my ($self, $parameters, $tier) = @_;
    my $url          = $self->base_url;
    my $merchant_id  = $self->merchant_id;
    my $redirect_url = $self->verify_url;
    my @params       = (
        MerchantID  => $merchant_id,
        RedirectURL => $redirect_url,
        EchoData    => $tier->{name},
        Amount      => $tier->{price} * 100
    );
    my $mkey = $self->calc_mkey(@params);
    my $query = join("&", pairmap {"$a=" . uri_escape($b)} @params, 'MKEY', $mkey);
    return "$url?$query";
}

sub iframe { 1 }


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

