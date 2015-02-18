package pf::sms_carrier;

=head1 NAME

pf::sms_carrier add documentation

=cut

=head1 DESCRIPTION

pf::sms_carrier

=cut

use strict;
use warnings;
use pf::db;
use pf::log;

use constant SMS_CARRIER => 'sms_carrier';

BEGIN {
    use Exporter ();
    our (@ISA, @EXPORT);
    @ISA    = qw(Exporter);
    @EXPORT = qw(sms_carrier_view_all);
}

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $sms_carrier_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $sms_carrier_statements = {};

=head1 SUBROUTINES

=head2 sms_carrier_db_prepare

=cut

sub sms_carrier_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::sms_carrier');
    $logger->debug("Preparing pf::sms_carrier database queries");

    $sms_carrier_statements->{'sms_carrier_view_all_sql'} = get_db_handle()->prepare(qq[
        SELECT id, name
        FROM sms_carrier
    ]);

    $sms_carrier_statements->{'sms_carrier_view_sql'} = qq[
        SELECT id, name
        FROM sms_carrier
        WHERE id IN (?)
    ];

    $sms_carrier_db_prepared = 1;
}

=head2 sms_carrier_view_all

=cut

sub sms_carrier_view_all {
    my $source = shift;
    my $query;

    # Check if a SMS authentication source is defined; if so, use the carriers list
    # from this source
    if ($source) {
        my $list = join(',', @{$source->{'sms_carriers'}});
        sms_carrier_db_prepare() unless ($sms_carrier_db_prepared);
        $sms_carrier_statements->{'sms_carrier_view_sql'} =~ s/\?/$list/;
        $query = db_query_execute(SMS_CARRIER, $sms_carrier_statements,
                                  'sms_carrier_view_sql');
    }
    else {
        # Retrieve all carriers
        $query = db_query_execute(SMS_CARRIER, $sms_carrier_statements,
                                  'sms_carrier_view_all_sql');
    }
    my $val = $query->fetchall_arrayref({});
    $query->finish();

    return $val;
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

