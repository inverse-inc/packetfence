package pf::billing::gateway::mirapay;

=head1 NAME

pf::billing::gateway::mirapay - Object oriented module for billing purposes

=cut

=head1 DESCRIPTION

pf::billing::gateway::mirapay is a module that implements billing
functions using the Mirapay payment gateway.

=cut

use strict;
use warnings;

use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use Readonly;
use Moo;
use pf::log;
use pf::billing::constants;
use pf::config;
use pf::billing::gateway::mirapay::request;

our $VERSION = 1.00;

Readonly our $DELIMITER => ',';

=head1 SUBROUTINES

=over

=cut

=item new

Constructor

Create a new object for transactions using Authorize.net payment gateway

=cut

has transactionInfo => (is => 'rw');

sub BUILDARGS {
    my ($class, $transactionInfo) = @_;
    if(ref($transactionInfo) eq 'HASH') {
        my $args;
        if (exists $transactionInfo->{transactionInfo} ) {
            $transactionInfo =  $transactionInfo->{transactionInfo};
        }
        if(exists $transactionInfo->{ccexpiration} ) {
            my $ccexpiration = $transactionInfo->{ccexpiration};
            $transactionInfo->{ccexpiration} = join('',reverse $ccexpiration =~ /^(\d\d)(\d\d)$/);
        }
        return { transactionInfo => $transactionInfo };
    }
    die "Invalid arguements";
}

#TODO finish the processPayment workflow
=item processPayment
    Processes the payment request against the mirapay system
=cut

sub processPayment {
    my ($self) = @_;
    my $logger     = get_logger();
    my $request    = $self->makeRequest;
    my $useragent  = LWP::UserAgent->new(protocols_allowed=>["https"]);
    my $response   = $useragent->request($request);
    $logger->debug(sub { "Request as string: " . $request->as_string });
    # There was an error processing the payment with the payment gateway
    if ( !$response->is_success ) {
        $logger->error("There was an error in the process of the payment: " . $response->status_line());
        return $BILLING::ERROR;
    }
    my $content = $response->content;
    $logger->debug(sub { "content of response $content" } );
    chomp($content);
    my %data = map { unpack 'a2 a*' } split /,/, $content;
    # Move code to constants
    my $approved_code = $data{AB};
    my $display_msg   = $data{DM} || 'Unknown error please contact your administrator';
    # The payment was not approved
    if ( !$approved_code || $approved_code ne 'Y' ) {
        $logger->error("The payment was not approved by the payment gateway: $display_msg");
        return $BILLING::ERROR;
    }
    $logger->info("Successfull payment from MAC: $self->{transactionInfo}{mac}");
    return $BILLING::SUCCESS;
}

sub makeRequest {
    my ($self) = @_;
    my $info = $self->transactionInfo;
    my $miraPayRequest = pf::billing::gateway::mirapay::request->new({
        amount => $info->{price},
        map {$_ => $info->{$_} } qw(ccnumber ccexpiration ccverification description)
    });
    return $miraPayRequest->makeRequest;
}


=back

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
