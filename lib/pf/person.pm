package pf::person;

=head1 NAME

pf::person - module for person management.

=cut

=head1 DESCRIPTION

pf::person contains the functions necessary to manage a person: creation,
deletion, read info, ...

=cut

use strict;
use warnings;
use pf::constants;
use pf::log;
use pf::password;
use DateTime;
use DateTime::Format::MySQL;

use constant PERSON => 'person';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        $person_db_prepared
        person_db_prepare

        person_exist
        person_delete
        person_add
        person_view
        person_count_all
        person_view_all
        person_view_simple
        person_modify
        person_nodes
        person_violations
        person_custom_search
        person_cleanup
        persons_without_nodes
        $PID_RE
    );
}

use pf::db;
use List::MoreUtils qw(any);

=head1 GLOBALS

=over

=cut

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $person_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $person_statements = {};

=item $unquoted_pid_re

Characters allowed in a person id (pid). This is stricter than what we have
in pf::pfcmd and pf::pfcmd::pfcmd

=cut

our $PID_RE = qr{ [a-zA-Z0-9\-\_\.\@\/\\]+ }x;

our @FIELDS = qw(
    pid firstname lastname email telephone company address notes sponsor anniversary
    birthday gender lang nickname cell_phone work_phone title building_number apartment_number
    room_number custom_field_1 custom_field_2 custom_field_3 custom_field_4 custom_field_5 custom_field_6
    custom_field_7 custom_field_8 custom_field_9 portal source
);

our @NON_PROMPTABLE_FIELDS = qw(pid sponsor portal source);

our @PROMPTABLE_FIELDS;
foreach my $field (@FIELDS){
    next if(any { $_ eq $field} @NON_PROMPTABLE_FIELDS);
    push @PROMPTABLE_FIELDS, $field;
}

=back

=head1 SUBROUTINES

=cut

sub person_db_prepare {
    my $logger = get_logger();
    $logger->debug("Preparing pf::person database queries");

    $person_statements->{'person_exist_sql'} = get_db_handle()->prepare(qq[ select count(*) from person where pid=? ]);

    $person_statements->{'person_add_sql'} = get_db_handle()->prepare(
        qq[ INSERT INTO person
                   (pid, firstname, lastname, email, telephone, company, address, notes, sponsor, anniversary,
                    birthday, gender, lang, nickname, cell_phone, work_phone, title,
                    building_number, apartment_number, room_number,
                    custom_field_1, custom_field_2, custom_field_3, custom_field_4, custom_field_5,
                    custom_field_6, custom_field_7, custom_field_8, custom_field_9, portal, source)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ]);

    $person_statements->{'person_view_sql'} = get_db_handle()->prepare(
        qq[ SELECT p.pid, p.firstname, p.lastname, p.email, p.telephone, p.company, p.address,
                   p.notes, p.sponsor, p.anniversary, p.birthday, p.gender, p.lang, p.nickname,
                   p.cell_phone, p.work_phone, p.title, p.building_number,
                   p.apartment_number, p.room_number, p.custom_field_1, p.custom_field_2,
                   p.custom_field_3, p.custom_field_4, p.custom_field_5, p.custom_field_6,
                   p.custom_field_7, p.custom_field_8, p.custom_field_9, p.portal, p.source,
                   count(n.mac) as nodes,
                   t.password, t.valid_from as 'valid_from', t.expiration as 'expiration',
                   t.access_duration as 'access_duration', t.access_level as 'access_level',
                   t.sponsor as 'can_sponsor', t.unregdate as 'unregdate',
                   nc.name as 'category'
            FROM person p
            LEFT JOIN node n ON p.pid = n.pid
            LEFT JOIN password t ON p.pid = t.pid
            LEFT JOIN node_category nc ON nc.category_id = t.category
            WHERE p.pid = ? ]);

    $person_statements->{'person_view_all_sql'} =
        qq[ SELECT p.pid, p.firstname, p.lastname, p.email, p.telephone, p.company, p.address,
                   p.notes, p.sponsor, p.anniversary, p.birthday, p.gender, p.lang, p.nickname,
                   p.cell_phone, p.work_phone, p.title, p.building_number,
                   p.apartment_number, p.room_number, p.custom_field_1, p.custom_field_2,
                   p.custom_field_3, p.custom_field_4, p.custom_field_5, p.custom_field_6,
                   p.custom_field_7, p.custom_field_8, p.custom_field_9, p.portal, p.source,
                   count(n.mac) as nodes,
                   t.password, t.valid_from as 'valid_from', t.expiration as 'expiration',
                   t.access_duration as 'access_duration', t.access_level as 'access_level',
                   t.sponsor as 'can_sponsor', t.unregdate as 'unregdate',
                   t.category as 'category'
            FROM person p
            LEFT JOIN node n ON p.pid = n.pid
            LEFT JOIN password t ON p.pid = t.pid
            GROUP BY pid ];

    $person_statements->{'person_count_all_sql'} = qq[ SELECT count(*) as nb FROM person ];

    $person_statements->{'person_delete_sql'} = get_db_handle()->prepare(qq[ delete from person where pid=? ]);

    $person_statements->{'person_modify_sql'} = get_db_handle()->prepare(
        qq[ UPDATE person
            SET pid=?, firstname=?, lastname=?, email=?, telephone=?, company=?, address=?, notes=?, sponsor=?,
                anniversary=?, birthday=?, gender=?, lang=?, nickname=?, cell_phone=?, work_phone=?,
                title=?, building_number=?, apartment_number=?, room_number=?, custom_field_1=?, custom_field_2=?,
                custom_field_3=?, custom_field_4=?, custom_field_5=?, custom_field_6=?, custom_field_7=?, custom_field_8=?,
                custom_field_9=?, portal=?, source=?
            WHERE pid=? ]);

    $person_statements->{'person_nodes_sql'} = get_db_handle()->prepare(
        qq[ SELECT mac, pid, regdate, unregdate, lastskip, status, user_agent, computername, device_class, time_balance, bandwidth_balance
            FROM node
            WHERE pid = ? ]);

    $person_statements->{'person_violations_sql'} = get_db_handle()->prepare(
        qq[ SELECT violation.id, violation.mac, violation.vid, class.description, start_date, release_date, violation.status
            FROM violation
            LEFT JOIN node ON violation.mac = node.mac
            LEFT JOIN class ON violation.vid = class.vid
            WHERE pid = ?
            ORDER BY start_date desc ]);

    $person_statements->{'person_view_simple_sql'} = get_db_handle()->prepare(
        qq[ SELECT pid, firstname, lastname, email, telephone, company, address,
                   notes, sponsor, anniversary, birthday, gender, lang, nickname,
                   cell_phone, work_phone, title, building_number,
                   apartment_number, room_number, custom_field_1, custom_field_2,
                   custom_field_3, custom_field_4, custom_field_5, custom_field_6,
                   custom_field_7, custom_field_8, custom_field_9, portal, source
            FROM person
            WHERE pid = ? ]);

    $person_statements->{'persons_without_nodes_sql'} = get_db_handle()->prepare(
        qq[
            SELECT person.pid as pid from person
            LEFT JOIN node on node.pid=person.pid
            GROUP BY pid
            HAVING count(node.mac)=0;
            ]);

    $person_db_prepared = 1;
}

#
#
#
sub person_exist {
    my ($pid) = @_;
    my $query = db_query_execute(PERSON, $person_statements, 'person_exist_sql', $pid) || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

#
# delete and return 1
#
sub person_delete {
    my ($pid) = @_;

    my $logger = get_logger();
    return (0) if ( $pid eq "admin" || $pid eq "default" );

    if ( !person_exist($pid) ) {
        $logger->error("delete of non-existent person '$pid' failed");
        return 0;
    }

    my @nodes = person_nodes($pid);
    if ( scalar(@nodes) > 0 ) {
        $logger->error( "person $pid has "
                . scalar(@nodes)
                . " node(s) registered in its name. Person deletion prohibited"
        );
        return 0;
    }

    db_query_execute(PERSON, $person_statements, 'person_delete_sql', $pid) || return (0);
    $logger->info("person $pid deleted");
    return (1);
}

#
# clean input parameters and add to person table
#
sub person_add {
    my ( $pid, %data ) = @_;
    my $logger = get_logger();

    if ( person_exist($pid) ) {
        $logger->error("attempt to add existing person $pid");
        return (2);
    }
    $data{pid} = $pid;
    db_query_execute(PERSON, $person_statements, 'person_add_sql', @data{@FIELDS}) || return (0);
    $logger->info("person $pid added");
    return (1);
}

#
# return row = pid
#
sub person_view {
    my ($pid) = @_;

    my $query  = db_query_execute(PERSON, $person_statements, 'person_view_sql', $pid)
        || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

sub person_view_simple {
    my ($pid) = @_;

    my $query  = db_query_execute(PERSON, $person_statements, 'person_view_simple_sql', $pid)
        || return (0);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

sub person_count_all {
    my ( %params ) = @_;
    my $logger = get_logger();

    # Hack! we prepare the statement here so that $person_count_all_sql is pre-filled
    person_db_prepare() if (!$person_db_prepared);
    my $person_count_all_sql = $person_statements->{'person_count_all_sql'};

    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $person_count_all_sql
                .= " WHERE pid='" . $params{'where'}{'value'} . "'";
        }
        elsif ( $params{'where'}{'type'} eq 'any' ) {
            if (exists($params{'where'}{'like'})) {
                $person_count_all_sql .= " WHERE"
                  . " pid LIKE " . get_db_handle->quote('%' . $params{'where'}{'like'} . '%')
                  . " OR firstname LIKE " . get_db_handle->quote('%' . $params{'where'}{'like'} . '%')
                  . " OR lastname LIKE " . get_db_handle->quote('%' . $params{'where'}{'like'} . '%')
                  . " OR email LIKE " . get_db_handle->quote('%' . $params{'where'}{'like'} . '%');
            }
        }
    }

    # Hack! Because of the nature of the query built here (we cannot prepare it), we construct it as a string
    # and pf::db will recognize it and prepare it as such
    $person_statements->{'person_count_all_sql_custom'} = $person_count_all_sql;
    $logger->debug($person_count_all_sql);

    return db_data(PERSON, $person_statements, 'person_count_all_sql_custom');
}

sub person_custom_search {
    my ($sql, @args) = @_;
    my $logger = get_logger();

    $person_statements->{'person_custom_search'} = $sql;
    return db_data(PERSON, $person_statements, 'person_custom_search', @args);
}

sub person_view_all {
    my ( %params ) = @_;
    my $logger = get_logger();

    # Hack! we prepare the statement here so that $person_view_all_sql is pre-filled
    person_db_prepare() if (!$person_db_prepared);
    my $person_view_all_sql = $person_statements->{'person_view_all_sql'};

    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $person_view_all_sql
                .= " HAVING p.pid='" . $params{'where'}{'value'} . "'";
        }
        elsif ( $params{'where'}{'type'} eq 'any' ) {
            my $like = get_db_handle->quote('%' . $params{'where'}{'like'} . '%');
            $person_view_all_sql .= " HAVING"
              . " pid LIKE $like"
              . " OR p.firstname LIKE $like"
              . " OR p.lastname LIKE $like"
              . " OR p.email LIKE $like";
        }
    }
    if ( defined( $params{'orderby'} ) ) {
        $person_view_all_sql .= " " . $params{'orderby'};
    }
    if ( defined( $params{'limit'} ) ) {
        $person_view_all_sql .= " " . $params{'limit'};
    }

    # Hack! Because of the nature of the query built here (we cannot prepare it), we construct it as a string
    # and pf::db will recognize it and prepare it as such
    $person_statements->{'person_view_all_sql_custom'} = $person_view_all_sql;
    $logger->debug($person_view_all_sql);

    return db_data(PERSON, $person_statements, 'person_view_all_sql_custom');
}

sub person_modify {
    my ( $pid, %data ) = @_;

    my $logger = get_logger();
    if ( !person_exist($pid) ) {
        if ( person_add( $pid, %data ) ) {
            $logger->warn(
                "modify of non-existent person $pid attempted - person added"
            );
            return (2);
        } else {
            $logger->error(
                "modify of non-existent person $pid attempted - person add failed"
            );
            return (0);
        }
    }
    my $existing = person_view($pid);
    foreach my $item ( keys(%data) ) {
        $existing->{$item} = $data{$item};
    }
    my $new_pid   = $existing->{'pid'};

    # compare pid case insensitively to prevent juser from not matching Juser
    if ( lc $pid ne lc $new_pid && person_exist($new_pid) ) {
        $logger->error(
            "modify of pid $pid to $new_pid conflicts with existing person");
        return (0);
    }

    db_query_execute(PERSON, $person_statements, 'person_modify_sql', @{$existing}{@FIELDS}, $pid) || return (0);
    $logger->info("person $pid modified to $new_pid") if ($pid ne $new_pid);
    return (1);
}

sub person_nodes {
    my ($pid) = @_;

    return db_data(PERSON, $person_statements, 'person_nodes_sql', $pid);
}

sub person_violations {
    my ($pid) = @_;

    return db_data(PERSON, $person_statements, 'person_violations_sql', $pid);
}

=head2 persons_without_nodes

Get all the persons who are not the owner of at least one node.

=cut

sub persons_without_nodes {
   return db_data(PERSON, $person_statements, 'persons_without_nodes_sql');
}

=head2 person_cleanup

Clean all persons that are not the owner of a node and that are not a local account that is still valid

=cut

sub person_cleanup {
    my @to_delete = map { $_->{pid} } persons_without_nodes();
    my $now = DateTime->now();
    foreach my $pid (@to_delete) {
        if($pf::constants::BUILTIN_USERS{$pid}){
            get_logger->debug("User $pid is set for deletion but is a built-in user. Not deleting...");
            next;
        }
        my $password = pf::password::view($pid);
        if(defined($password)){
            my $expiration = $password->{expiration};
            if ($expiration eq '0000-00-00 00:00:00' ) {
                get_logger->debug("Not deleting $pid because the password is set not to expire");
                next;
            }
            $expiration = DateTime::Format::MySQL->parse_datetime($expiration);
            my $cmp = DateTime->compare($now, $expiration);
            if($cmp < 0){
                get_logger->debug("Not deleting $pid because the local account is still valid.");
                next;
            }
            # We delete the password too
            pf::password::_delete($pid);
        }
        # We're all good for deletion
        person_delete($pid);
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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

