package pf::billing::gateway::mirapay::request;
=head1 NAME

pf::billing::gateway::mirapay::request add documentation

=cut

=head1 DESCRIPTION

pf::billing::gateway::mirapay::request

=cut

use strict;
use warnings;
use Moo;
use pf::billing::gateway::mirapay::response;
use Digest::SHA1 qw(sha1_hex);
use DateTime;
use pf::log;
use pf::config;
use HTTP::Request;

our %TYPES = (
    messageType => 'AN',
    termId => 'AN',
    termIdGroup => 'AN',
    transCode => 'AN',
    track2Acc => 'AN',
    amount1 => 'N',
    mKey => 'AN',
    approvalCd => 'AN',
    invoiceNum => 'AN',
    dateTimeFormated => 'AN',
    operatorID => 'N',
    extendedOpId => 'AN',
    operatorLanguage => 'N',
    echoData => 'AN',
    accountType => 'AN',
    description => 'AN',
    ccverification => 'N',
    addressLine1 => 'AN',
    zip => 'AN',
    transactionHandle => 'AN'
);

our %SHORT_CODE_TO_NAME = (
    MT => 'messageType',
    TI => 'termId',
    TG => 'termIdGroup',
    TC => 'transCode',
    T2 => 'track2Acc',
    A1 => 'amount1',
    MY => 'mKey',
    AC => 'approvalCd',
    IN => 'invoiceNum',
    DT => 'dateTimeFormated',
    OP => 'operatorID',
    EO => 'extendedOpId',
    OL => 'operatorLanguage',
    ED => 'echoData',
    AY => 'accountType',
    LD => 'description',
    CV => 'ccverification',
    D1 => 'addressLine1',
    ZP => 'zip',
    H0 => 'transactionHandle',
);

our %NAME_TO_SHORT_CODE = reverse %SHORT_CODE_TO_NAME;

has messageType => (
    is      => 'rw',
    default => sub { 'Q' },
    required => 1,
);

has [qw(
    ccexpiration
    ccnumber
    ccverification
    amount
    approvalCd
    invoiceNum
    operatorID
    extendedOpId
    operatorLanguage
    echoData
    description
    cvvCode
    addressLine1
    zip
    transactionHandle
    )
] => (is => 'rw');

has transCode => (
    is      => 'rw',
    default => sub { $Config{billing}{mirapay_currency} eq 'USD' ? 12 : 27 },
    required => 1,
);

has termId => (
    is => 'rw',
    default => sub { $Config{billing}{mirapay_terminal_id} }
);

has termIdGroup => (
    is => 'rw',
    default => sub { $Config{billing}{mirapay_terminal_id_group} }
);

has dateTime => (
    is => 'rw',
    isa => sub { DateTime->isa($_[0]) },
    default => sub { DateTime->now }
);

has hashPassword => (
    is => 'rw',
    default => sub { $Config{billing}{mirapay_hash_password} }
);

sub accountType {
    my ($self) = @_;
    return $Config{billing}{mirapay_currency} eq 'USD' ? 'BE' : undef;
}

sub amount1 {
    my ($self) = @_;
    my $amount = $self->amount;
    if(defined $amount) {
        $amount = sprintf("%.0f",$amount * 100);
    }
    return $amount;
}

sub dateTimeFormated {
    my ($self) = @_;
    $self->dateTime->strftime("%Y%m%d%H%M%S");
}

sub mKey {
    my ($self) = @_;
    my $key = join('',map { my $val = $self->$_; die "$_ is not defined" unless defined $val; $val} qw(hashPassword termId transCode amount1 dateTimeFormated));
    unless(defined $self->transactionHandle) {
        $key .= $self->track2Acc;
    }
    return sha1_hex($key);
}

sub track2Acc {
    my ($self) = @_;
    my $cc = $self->ccnumber;
    my $ccexpiration = $self->ccexpiration;
    my $value;
    if(defined $cc && defined $ccexpiration) {
        $value =  join('', "M", $cc, '=', $ccexpiration, '1?');
    }
    return $value;
}



sub makeRequestQuery {
    my ($self) = @_;
    my $query = '';
    my @queries;
    foreach my $attr (
        qw( messageType termId termIdGroup transCode track2Acc amount1 mKey approvalCd invoiceNum dateTimeFormated operatorID extendedOpId operatorLanguage echoData accountType cvvCode addressLine1 zip transactionHandle)
        ) {
        my $value = $self->$attr;
        push @queries, $NAME_TO_SHORT_CODE{$attr} . $value if defined $value && $value ne '';
    }
    return join(",",@queries) . "\n";
}

sub url {
    return $Config{billing}{mirapay_url};
}

sub makeRequest {
    my ($self) = @_;
    return HTTP::Request->new(GET => join('',$self->url,"?",$self->makeRequestQuery));
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

