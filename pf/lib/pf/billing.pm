package pf::billing;

=head1 NAME

pf::billing - Object oriented module for billing purposes

=cut

=head1 DESCRIPTION

pf::billing is a module to add billing capabilities to the captive-portal to allow guest to pay for network access.
All of the methods of this module can be redefined using pf:billing:custom in lib/pf/billing/custom.pm

=cut

use strict;
use warnings;

use Log::Log4perl;
use Net::MAC;
use POSIX;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw($billing_db_prepared billing_db_prepare);
    @EXPORT_OK = qw(
        billing_insert_sql
        billing_update_sql
    );
}

use pf::billing::constants;
use pf::config;
use pf::db;
use pf::util;

use constant BILLING => 'billing';

our $VERSION = 1.00;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $billing_db_prepared = 0;

# In this hash reference we hold the database statements. We pass it to the query handler and it will repopulate
# the hash if required.
our $billing_statements = {};

=head1 SUBROUTINES

=over

=cut

=item billing_db_prepare

Initialize database prepared statements

=cut
sub billing_db_prepare {
    $billing_statements->{'billing_insert_sql'} = get_db_handle()->prepare(qq[
            INSERT INTO billing (
                id, ip, mac, type, start_date, update_date, status, item, price, person
            ) VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
    ]);

    $billing_statements->{'billing_update_sql'} = get_db_handle()->prepare(qq[
            UPDATE billing SET
                status = ?
            WHERE id = ?
    ]);

    $billing_db_prepared = 1;
    return 1;
}

=item new

Constructor

Usually we don't call this constructor but we use the pf::billing::custom subclass instead.
This will allow methods redefinition.

=cut
sub new {
    my ( $class, %argv ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Instanciating a new pf:billing object");

    my $this = bless {}, $class;

    return $this;
}

=item createNewTransaction

TODO: Add some verification that all the information is there and in a good format.

=cut
sub createNewTransaction {
    my ( %transaction_infos ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # Preparing the transaction attributes
    # slicing hash on the right assigning proper values to the left
    my ($ip, $mac, $item, $price, $email) = @transaction_infos{qw(ip mac item price email)};

    my $epoch   = time;
    my $date    = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime($epoch));
    my $id      = generate_id($epoch, $mac);
    my $type    = lc($Config{'billing'}{'gateway'});

    # Update transaction informations
    $transaction_infos{'id'} = $id;

    # Adding an entry in the database to keep track of the transactions
    db_query_execute(BILLING, $billing_statements, 'billing_insert_sql',
            $id, $ip, $mac, $type, $date, '0000-00-00 00:00:00', 'new', $item, $price, $email
    ) || return 0;

    # Instantiate the new transaction
    my $transaction = instantiateNewTransaction($type, %transaction_infos);

    return $transaction;
}

=item getAvailableTiers

Provide available tiers informations for different Internet access.
For modification purposes (add tiers, modify tiers infos) please refer to pf::billing::custom. This way, modifications
won't be overwritten when upgrading.

TODO: Put theses configuration in database and be able to modify them using the web GUI

=cut
sub getAvailableTiers {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my %tiers = (
            tier1 => {
                id => "tier1", name => "Tier 1", price => "1.00", timeout => "1D", category => 'default',
                description => "Tier 1 Internet Access", destination_url => "http://www.packetfence.org" },
    );

    return %tiers;
}

=item instantiateNewTransaction

Instantiate a new transaction using the payment gateway configured.

=cut
sub instantiateNewTransaction {
    my ( $type, %transaction_infos ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $transaction = 'pf::billing::gateway::' . $type;

    return $transaction->new(%transaction_infos);
}

=item processTransaction

=cut
sub processTransaction {
    my ( %transaction_infos ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # Create the new transaction
    my $transaction = createNewTransaction(%transaction_infos);

    # Process the payment with the payment gateway
    my $paymentResponse = $transaction->processPayment();

    # Update transaction status in database
    my $status = $BILLING::STATUS_PROCESSED_SUCCESS;
    if ( $paymentResponse ne $BILLING::SUCCESS ) {
        $status = $BILLING::STATUS_PROCESSED_ERROR;
    }
    updateTransactionStatus($transaction_infos{'id'}, $status);

    return $paymentResponse;
}

=item updateTransactionStatus

Update the status of a transaction in the database

=cut
sub updateTransactionStatus {
    my ( $id, $status ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Updating the transaction: $id with status: $status");

    db_query_execute(BILLING, $billing_statements, 'billing_update_sql', $status, $id ) || return 0;
}

=back

=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011-2012 Inverse inc.

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
