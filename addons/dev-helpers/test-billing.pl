#!/usr/bin/perl
=head1 NAME

test add documentation

=head1 SYNOPSIS

    test-billing.pl options

    Manditory options:
    --ip IP                Ip address of node
    --mac MAC              Mac of noe
    --firstname FIRSTNAME  Firstname
    --lastname LASTNAME    Lastname
    --email EMAIL          Email address
    --ccnumber CC          Creditcard number
    --ccexpiration EXP     Creditcard expiraction date MMYY
    --ccverification VCODE Creditcard verification id
    --item ITEM            Item description
    --price PRICE          The price of the item
    --description DESC     Description of the invoice

    Optional options
    --help

=head1 DESCRIPTION

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::billing::custom;
use pf::billing::constants;
use pf::billing::gateway::mirapay::request;
use Getopt::Long;
use Pod::Usage;

my %transaction_infos;
GetOptions (\%transaction_infos,
    'ip=s',
    'mac=s',
    'firstname=s',
    'lastname=s',
    'email=s',
    'ccnumber=s',
    'ccexpiration=s',
    'ccverification=s',
    'item=s',
    'price=s',
    'description=s',
    'help',
) or pod2usage(2);

pod2usage(1) if $transaction_infos{help};

my @notThere =
    grep {! (exists $transaction_infos{$_} && $transaction_infos{$_} ) }
    qw(
        ip mac firstname lastname email ccnumber
        ccexpiration ccverification item price description
    )
;

if(@notThere) {
    pod2usage(-msg => join("\n","Following options not provided:",@notThere,''),-exitval => 1);
}

my $billingObj = new pf::billing::custom();

# Transactions informations
my $transaction_infos_ref = {
        ip              => '192.168.1.1',
        mac             => '01:01:01:01:01:01',
        firstname       => 'James',
        lastname        => 'Rouzier',
        email           => 'jrouzier@inverse.ca',
        ccnumber        => '4601720000000891',
        ccexpiration    => '1213',
        ccverification  => '012',
        item            => 'Item name',
        price           => 100,
        description     => 'Test'
};

# Process the transaction
my $paymentStatus   = $billingObj->processTransaction(\%transaction_infos);

if($paymentStatus eq $BILLING::SUCCESS) {
    print "Was successful\n";
} else {
    print "Failed\n";
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

