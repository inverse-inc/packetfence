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
use DateTime;
use HTTP::Request;
use Moose;
use pf::log;
use pf::config qw($default_pid $fqdn);
use pf::constants qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::util;
use List::Util qw(pairmap);
use Readonly;

our %SHORT_CODE_TO_NAME = (
    A1 => 'amount',
    AB => 'approved',
    AC => 'approvalCode',
    AT => 'cardType',
    AY => 'accountType',
    B1 => 'accountBalance',
    BA => 'bankAccount',
    BR => 'bankRoute',
    CE => 'cvvResponse',
    CV => 'ccverification',
    D1 => 'addressLine1',
    DM => 'displayMsg',
    DT => 'date',
    ED => 'echoData',
    EO => 'extendedOperatorID',
    EX => 'expirationDate',
    H0 => 'transactionHandle',
    ID => 'idSeqNumber',
    IN => 'invoice_num',
    IR => 'isoResponseCode',
    LD => 'description',
    MA => 'receiptMsgAccount',
    MT => 'messageType',
    MY => 'mkey',
    OL => 'operatorLanguage',
    OM => 'operatorMessage',
    OP => 'operatorID',
    RA => 'receiptMsgAction',
    RC => 'responseCode',
    RM => 'receiptMsg',
    RN => 'receiptRefNum',
    SO => 'shortToken',
    T2 => 'track2Acc',
    TC => 'transCode',
    TG => 'terminalIdGroup',
    TI => 'terminalId',
    TK => 'token',
    TR => 'transactionCounter',
    VM => 'avsResponseM',
    VR => 'avsResponseC',
    ZP => 'zip',
);

our %NAME_TO_SHORT_CODE = reverse %SHORT_CODE_TO_NAME;

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

has direct_base_url => (
    is => 'rw',
    default => "https://staging.eigendev.com/OFT/EigenOFT_d.php",
);

has service_fqdn => (
    is => 'rw',
);

has shared_secret => (
    is => 'rw',
    required => 1,
);

has merchant_id => (
    is => 'rw',
    required => 1,
);

has terminal_id => (
    is => 'rw',
    required => 1,
);

has terminal_group_id => (
    is => 'rw',
);

has shared_secret_direct => (
    is => 'rw',
    required => 1,
);

=head2 prepare_payment

Prepare the payment from mirapay

=cut

sub prepare_payment {
    my ($self, $session, $tier, $params, $uri) = @_;
    my $hash = {
        mirapay_url => $self->make_mirapay_iframe_url($params, $tier),
    };
    return $hash;
}

=head2 verify

Verify the payment from mirapay

=cut

sub verify {
    my ($self, $session, $parameters, $uri) = @_;
    my $id = $self->id;
    my $logger = get_logger();
    $logger->trace( sub {"Verifing $uri for source $id"});
    my $action_code = $parameters->{'ActionCode'} // $MIRAPAY_ACTION_CODE_DECLINED;
    if($MIRAPAY_ACTION_CODE_APPROVED ne $action_code) {
        die "Transaction declined";
    }
    unless ($self->verify_mkey($self->shared_secret, $uri->query)) {
        die "Invalid transaction provided";
    }
    my $results = $self->submit_approval_code($session, $parameters, $uri);
    if ($results->{approved} eq 'N') {
        $logger->error( "Source $id Cannot submit approval code Error : " . $results->{operatorMessage});
        die "Transaction failed";
    }
    return $results;
}

=head2 submit_approval_code

submit approval code to mirapay direct

=cut

sub submit_approval_code {
    my ($self, $session, $parameters, $uri) = @_;
    my $logger = get_logger();
    my $id = $self->id;
    my $url = $self->make_mirapay_direct_url($session, $parameters, $uri);
    $logger->trace(sub { "Submitted url to mirapay direct for $id : $url"});
    my $request = HTTP::Request->new(GET => $url);
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($request);
    if ( !$response->is_success ) {
        die "Cannot Problem submitting approval code\n";
    }
    my $content = $response->content;
    $logger->trace(sub { "Response back from mirapay direct for $id : $content"});
    my $results = $self->parse_mirapay_direct_response($content);
    return $results;
}

=head2 parse_mirapay_direct_response

parse_mirapay_direct_response

=cut

sub parse_mirapay_direct_response {
    my ($self, $content) = @_;
    my %unparsed;
    my %response = (unparsed => \%unparsed);;
    #Split by an unescaped comma
    foreach my $data (split (/(?<!\\),/, $content)) {
        my $type = substr($data, 0, 2);
        my $value = substr($data, 2);
        $value =~ s/\\,/,/g;
        if (exists $SHORT_CODE_TO_NAME{$type}) {
            $response{$SHORT_CODE_TO_NAME{$type}} = $value;
        }
        else {
            $unparsed{$type} = $value;
        }
    }
    return \%response;
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
    my ($self, $shared_secret, @params) = @_;
    sha256_hex(@params, $shared_secret);
}

sub verify_mkey {
    my ($self, $shared_secret, $query) = @_;
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
    my $test_key = $self->calc_mkey($shared_secret, @params);
    return $test_key eq $mkey ;
}

=head2 make_mirapay_direct_url

make_mirapay_direct_url

=cut

sub make_mirapay_direct_url {
    my ($self, $session, $parameters, $uri) = @_;
    my $tier    = $session->{'tier'};
    my $options = $self->build_mirapay_direct_options($parameters, $tier);
    my @queries;
    while (my ($key, $value) = each %$options) {
        push @queries, $NAME_TO_SHORT_CODE{$key} . $value if defined $value && $value ne '';
    }
    return $self->direct_base_url . "?" . join(",", @queries) . "\n";
}

=head2 build_mirapay_direct_options

build the mirapay direct options

=cut

sub build_mirapay_direct_options {
    my ($self, $parameters, $tier) = @_;
    my $group_id     = $self->terminal_group_id;
    my %options = (
        transCode     => '27',
        approvalCode  => $parameters->{ApprovalCode},
        token         => $parameters->{EigenToken},
        date          => DateTime->now->strftime("%Y%m%d%H%M%S"),
        amount => $tier->{price} * 100,
    );
    if (defined $group_id && length($group_id) ) {
        $options{terminalIdGroup} = $group_id;
    }
    else {
        $options{terminalId} = $self->terminal_id;
    }
    $options{mkey} = $self->mirapay_direct_hash($self->shared_secret_direct, \%options);
    return \%options;
}

=head2 make_mirapay_iframe_url

Make Mirapay Iframe URL

=cut

sub make_mirapay_iframe_url {
    my ($self, $parameters, $tier) = @_;
    my $url          = $self->base_url;
    my $merchant_id  = $self->merchant_id;
    my $redirect_url = $self->verify_url;
    my @params       = (
        MerchantID  => $merchant_id,
        RedirectURL => $redirect_url,
        EchoData    => $tier->{name},
        Amount      => $tier->{price} * 100,
    );
    my $query = $self->make_query_with_mkey($self->shared_secret, \@params);
    return "$url?$query";
}

=head2 make_query_with_mkey

make_query_with_mkey

=cut

sub make_query_with_mkey {
    my ($self, $secret, $params) = @_;
    my $mkey = $self->calc_mkey($secret, @$params);
    return join("&", pairmap {"$a=" . uri_escape($b)} @$params, 'MKEY', $mkey);
}

sub _build_base_path {
    my ($self) = @_;
    my $id     = $self->id;
    my $alt_fqdn = $self->service_fqdn || $fqdn;
    my $base_path = "https://$alt_fqdn/billing/$id";
    return $base_path;
}

sub mirapay_direct_hash {
    my ($self, $shared_secret, $options) = @_;
    return sha256_hex($shared_secret, $self->terminal_id, $options->{transCode}, $options->{amount}, $options->{date}, $options->{token});
}

=head2 iframe

iframe

=cut

sub iframe { 1 }

=head2 additionalConfirmationInfo

additionalConfirmationInfo

=cut

sub additionalConfirmationInfo {
    my ($self, $parameters, $tier, $session) = @_;
    return (
        transaction_id => $session->{verify_data}{receiptRefNum}
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

