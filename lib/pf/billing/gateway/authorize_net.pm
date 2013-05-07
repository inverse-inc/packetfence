package pf::billing::gateway::authorize_net;

=head1 NAME

pf::billing::gateway::authorize_net - Object oriented module for billing purposes

=cut

=head1 DESCRIPTION

pf::billing::gateway::authorize_net is a module that implements billing 
functions using the Authorize.net payment gateway.

=cut

use strict;
use warnings;

use HTTP::Request::Common qw(POST);
use Log::Log4perl;
use LWP::UserAgent;
use Readonly;

use pf::billing::constants;
use pf::config;

our $VERSION = 1.00;

Readonly our $DELIMITER => ',';

=head1 SUBROUTINES

=over

=cut

=item new

Constructor

Create a new object for transactions using Authorize.net payment gateway

=cut
sub new {
    my ( $class, $transaction_infos_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Instanciating a new " . __PACKAGE__ . " object");

    my $this = bless {
            # Transaction informations
            '_id'                   => undef,
            '_ip'                   => undef,
            '_mac'                  => undef,
            '_item'                 => undef,
            '_description'          => undef,
            '_price'                => undef,
            '_person'               => undef,

            # Client informations
            '_ccnumber'             => undef,
            '_ccexpiration'         => undef,
            '_ccverification'       => undef,
            '_firstname'            => undef,
            '_lastname'             => undef,
            '_email'                => undef,

            # Authorize.net specific attributes
            '_authorizenet_login'   => $Config{'billing'}{'authorizenet_login'},
            '_authorizenet_trankey' => $Config{'billing'}{'authorizenet_trankey'},
            '_authorizenet_posturl' => $Config{'billing'}{'authorizenet_posturl'},
    }, $class;

    foreach my $value ( keys %$transaction_infos_ref ) {
        $this->{'_' . $value} = $transaction_infos_ref->{$value};
    }

    return $this;
}

=item processPayment

=cut
sub processPayment {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $post_values = {
            x_login           => $this->{'_authorizenet_login'},
            x_tran_key        => $this->{'_authorizenet_trankey'},
            x_card_num        => $this->{'_ccnumber'},
            x_exp_date        => $this->{'_ccexpiration'},
            x_card_code       => $this->{'_ccverification'},

            x_invoice_num     => $this->{'_id'},
            x_description     => $this->{'_description'},
            x_amount          => $this->{'_price'},
            x_first_name      => $this->{'_firstname'},
            x_last_name       => $this->{'_lastname'},
            x_email           => $this->{'_email'},

            x_type            => 'AUTH_CAPTURE',
            x_version         => '3.1',
            x_delim_data      => 'TRUE',
            x_delim_char      => $DELIMITER,
            x_relay_response  => 'FALSE',
            x_email_customer  => 'TRUE',
    };

    my $useragent   = LWP::UserAgent->new(protocols_allowed=>["https"]);
    my $request     = POST($this->{'_authorizenet_posturl'}, $post_values);
    my $response    = $useragent->request($request);

    # There was an error processing the payment with the payment gateway
    if ( !$response->is_success ) {
        $logger->error("There was an error in the process of the payment: " . $response->status_line());
        return;
    }

    my @response = split(/$DELIMITER/, $response->content);
    my $response_code           = $response[$AUTHORIZE_NET::RESPONSE_CODE];
    my $response_reason_text    = $response[$AUTHORIZE_NET::RESPONSE_REASON_TEXT];

    # The payment was not approved
    if ( $response_code ne $AUTHORIZE_NET::APPROVED ) {
        $logger->error("The payment was not approved by the payment gateway: $response_reason_text");
        return;
    }
    $logger->info("Successfull payment from MAC: $this->{_mac}");

    return $BILLING::SUCCESS;
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
