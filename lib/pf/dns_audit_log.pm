package pf::dns_audit_log;

=head1 NAME

pf::dns_audit_log - module for dns_audit_log management.

=cut

=head1 DESCRIPTION

pf::dns_audit_log contains the functions necessary to manage a dns_audit_log: creation,
deletion, read info, ...

=cut

use strict;
use warnings;
use constant DNS_AUDIT_LOG => 'dns_audit_log';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        $dns_audit_log_db_prepared
        dns_audit_log_db_prepare
        dns_audit_log_delete
        dns_audit_log_add
        dns_audit_log_view
        dns_audit_log_count_all
        dns_audit_log_view_all
        dns_audit_log_cleanup
    );
}

use pf::log;
use pf::error qw(is_success is_error);
use pf::dal::dns_audit_log;
use pf::db;

our $logger = get_logger();

our @FIELDS = qw(
    ip
    mac
    qname
    qtype
    answer
);

=head1 SUBROUTINES

=head2 $success = dns_audit_log_delete($id)

Delete a dns_audit_log entry

=cut

sub dns_audit_log_delete {
    my ($id) = @_;
    my $status = pf::dal::dns_audit_log->remove_by_id({id => $id});
    return (is_success($status));
}


=head2 $success = dns_audit_log_add(%args)

Add a dns_audit_log entry

=cut

sub dns_audit_log_add {
    my %data = @_;
    my $item = pf::dal::dns_audit_log->new(\%data);
    my $status = $item->insert;
    return (is_success($status));
}

=head2 $entry = dns_audit_log_view($id)

View a dns_audit_log entry by it's id

=cut

sub dns_audit_log_view {
    my ($id) = @_;
    my ($status, $item) = pf::dal::dns_audit_log->find({id=>$id});
    if (is_error($status)) {
        return (0);
    }
    return ($item->to_hash());
}

=head2 $count = dns_audit_log_count_all()

Count all the entries dns_audit_log

=cut

sub dns_audit_log_count_all {
    my ($status, $count) = pf::dal::dns_audit_log->count;
    return $count;
}

=head2 @entries = dns_audit_log_view_all($offset, $limit)

View all the dns_audit_log for an offset limit

=cut

sub dns_audit_log_view_all {
    my ($offset, $limit) = @_;
    $offset //= 0;
    $limit  //= 25;
    my ($status, $iter) = pf::dal::dns_audit_log->search(
        -offset => $offset,
        -limit => $limit,
    );
    return if is_error($status);
    my $items = $iter->all();
    return @$items;
}

=head2 dns_audit_log_cleanup($expire_seconds, $batch, $time_limit)

Cleans up the dns_audit_log_cleanup table

=cut

sub dns_audit_log_cleanup {
    my $timer = pf::StatsD::Timer->new( { sample_rate => 0.2 } );
    my ( $expire_seconds, $batch, $time_limit ) = @_;
    my $logger = get_logger();
    $logger->debug( sub { "calling dns_audit_log_cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit"; });

    if ( $expire_seconds eq "0" ) {
        $logger->debug("Not deleting because the window is 0");
        return;
    }
    my $now        = pf::dal->now();
    my %search = (
        -where => {
            created_at => {
                "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
            },
        },
        -limit => $batch,
        -no_auto_tenant_id => 1,
    );
    pf::dal::dns_audit_log->batch_remove(\%search, $time_limit);
    return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
