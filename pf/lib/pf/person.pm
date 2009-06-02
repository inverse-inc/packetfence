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
use Log::Log4perl;

our (
    $person_modify_sql, $person_exist_sql, $person_delete_sql,
    $person_add_sql,    $person_view_sql,  $person_view_all_sql,
    $person_nodes_sql,  $person_db_prepared
);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT
        = qw(person_db_prepare person_exist person_delete person_add person_view person_view_all person_modify person_nodes);
}

use pf::db;

$person_db_prepared = 0;

#person_db_prepare($dbh) if (!$thread);

sub person_db_prepare {
    my ($dbh) = @_;
    db_connect($dbh);
    my $logger = Log::Log4perl::get_logger('pf::person');
    $logger->debug("Preparing pf::person database queries");
    $person_exist_sql
        = $dbh->prepare(qq[ select count(*) from person where pid=? ]);
    $person_add_sql
        = $dbh->prepare(qq[ insert into person(pid,firstname,lastname,email,telephone,company,address,notes) values(?,?,?,?,?,?,?,?) ]);
    $person_delete_sql = $dbh->prepare(qq[ delete from person where pid=? ]);
    $person_modify_sql
        = $dbh->prepare(qq[ update person set pid=?,firstname=?,lastname=?,email=?,telephone=?,company=?,address=?,notes=? where pid=? ]);
    $person_nodes_sql
        = $dbh->prepare(
        qq[ select mac,pid,regdate,unregdate,lastskip,status,user_agent,computername,dhcp_fingerprint from node where pid=? ]
        );
    $person_db_prepared = 1;
}

#
#
#
sub person_exist {
    my ($pid) = @_;
    person_db_prepare($dbh) if ( !$person_db_prepared );
    $person_exist_sql->execute($pid) || return (0);
    my ($val) = $person_exist_sql->fetchrow_array();
    $person_exist_sql->finish();
    return ($val);
}

#
# delete and return 1
#
sub person_delete {
    my ($pid) = @_;
    person_db_prepare($dbh) if ( !$person_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::person');
    return (0) if ( $pid eq "1" );

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

    $person_delete_sql->execute($pid) || return (0);
    $logger->info("person $pid deleted");
    return (1);
}

#
# clean input parameters and add to person table
#
sub person_add {
    my ( $pid, %data ) = @_;
    person_db_prepare($dbh) if ( !$person_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::person');
    if ( person_exist($pid) ) {
        $logger->error("attempt to add existing person $pid");
        return (2);
    }
    $person_add_sql->execute( $pid, $data{'firstname'},$data{'lastname'},$data{'email'}, $data{'telephone'}, $data{'company'}, $data{'address'}, $data{'notes'} ) || return (0);
    $logger->info("person $pid added");
    return (1);
}

#
# return row = pid
#
sub person_view {
    my ($pid) = @_;
    person_db_prepare($dbh) if ( !$person_db_prepared );
    $person_view_sql
        = $dbh->prepare("select pid,firstname,lastname,email,telephone,company,address,notes from person where pid=?");
    $person_view_sql->execute($pid) || return (0);
    my $ref = $person_view_sql->fetchrow_hashref();

    # just get one row and finish
    $person_view_sql->finish();
    return ($ref);
}

sub person_view_all {
    person_db_prepare($dbh) if ( !$person_db_prepared );
    $person_view_all_sql 
        = $dbh->prepare("select pid,firstname,lastname,email,telephone,company,address,notes from person");
    return db_data($person_view_all_sql);
}

sub person_modify {
    my ( $pid, %data ) = @_;
    use Data::Dumper;
    print Dumper(%data);
    person_db_prepare($dbh) if ( !$person_db_prepared );
    my $logger = Log::Log4perl::get_logger('pf::person');
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
    print Dumper($existing);
    my $new_pid   = $existing->{'pid'};
    my $new_notes = $existing->{'notes'};

    if ( $pid ne $new_pid && person_exist($new_pid) ) {
        $logger->error(
            "modify of pid $pid to $new_pid conflicts with existing person");
        return (0);
    }
print "calling person_modify_sql\n";
    $person_modify_sql->execute( 
        $new_pid,                 $existing->{'firstname'},
        $existing->{'lastname'},  $existing->{'email'},
        $existing->{'telephone'}, $existing->{'company'},
        $existing->{'address'},   $new_notes, 
        $pid 
    ) || return (0);
    $logger->info("person $pid modified to $new_pid");
    return (1);
}

sub person_nodes {
    my ($pid) = @_;
    person_db_prepare($dbh) if ( !$person_db_prepared );
    return db_data( $person_nodes_sql, $pid );
}

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2009 Inverse inc.

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
