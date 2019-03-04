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
        person_exist
        person_delete
        person_add
        person_view
        person_count_all
        person_view_all
        person_view_simple
        person_modify
        person_nodes
        person_security_events
        person_cleanup
        persons_without_nodes
        person_unassign_nodes
        $PID_RE
    );
}

use pf::dal::person;
use pf::dal::node;
use pf::dal::security_event;
use pf::error qw(is_error is_success);
use List::MoreUtils qw(any);

=head1 GLOBALS

=over

=cut


=item $unquoted_pid_re

Characters allowed in a person id (pid). This is stricter than what we have
in pf::pfcmd and pf::pfcmd::pfcmd

=cut

our $PID_RE = qr{ [a-zA-Z0-9\-\_\.\@\/\\]+ }x;

our @FIELDS = @pf::dal::_person::FIELD_NAMES;

our @NON_PROMPTABLE_FIELDS = qw(pid sponsor portal source tenant_id);

our @PROMPTABLE_FIELDS;
foreach my $field (@FIELDS){
    next if(any { $_ eq $field} @NON_PROMPTABLE_FIELDS);
    push @PROMPTABLE_FIELDS, $field;
}

=back

=head1 SUBROUTINES

=cut

#
#
#
sub person_exist {
    my ($pid) = @_;
    my $status = pf::dal::person->exists({pid => $pid});
    return (is_success($status));
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
    my ($status, $count) = pf::dal::node->count(
        -where => {
            pid => $pid
        }
    );
    if ( $count ) {
        $logger->error("person $pid has $count node(s) registered in its name. Person deletion prohibited");
        return 0;
    }
    $status = pf::dal::person->remove_by_id({pid => $pid});
    my $result = is_success($status);
    if ($result) {
        $logger->info("person $pid deleted");
    }
    return ($result);
}

#
# clean input parameters and add to person table
#
sub person_add {
    my ( $pid, %data ) = @_;
    my $logger = get_logger();
    $data{pid} = $pid;
    my $status = pf::dal::person->create(\%data);

    if ( $status == $STATUS::CONFLICT ) {
        $logger->error("attempt to add existing person $pid");
        return (2);
    }
    my $result = is_success($status);
    if ($result) {
        $logger->info("person $pid added");
    }
    return ($result);
}

#
# return row = pid
#
sub person_view {
    my ($pid) = @_;
    my ($status, $item) = pf::dal::person->find({pid => $pid});
    if (is_error($status)) {
        return (0)
    }
    return ($item->to_hash);
}

sub person_view_simple {
    my ($pid) = @_;
    my ($status, $iter) = pf::dal::person->search(
        -where => {
            pid => $pid,
        },
        -columns => \@FIELDS,
        # Don't do the full join
        -from => pf::dal::person->table,
    );
    if (is_error($status)) {
        return (0)
    }
    my $ref = $iter->next(undef);
    return ($ref);
}

sub person_count_all {
    my ( %params ) = @_;
    my $logger = get_logger();
    my $where = {};

    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $where->{pid} = $params{'where'}{'value'};
        }
        elsif ( $params{'where'}{'type'} eq 'any' ) {
            if (exists($params{'where'}{'like'})) {
                my $like = $params{'where'}{'like'};
                my $like_op = {"-like" => "%${like}%"};
                $where = [pid => $like_op, firstname => $like_op, lastname => $like_op, email => $like_op];
            }
        }
    }
    my ($status, $count) = pf::dal::person->count(
        -where => $where
    );
    return {nb => $count};
}

sub person_view_all {
    my ( %params ) = @_;
    my $logger = get_logger();
    my %where;
    my %search  = (
            -where => \%where,
            -group_by => 'person.pid',
    );

    if ( defined( $params{'where'} ) ) {
        if ( $params{'where'}{'type'} eq 'pid' ) {
            $where{pid} = $params{'where'}{'value'};
        }
        elsif ( $params{'where'}{'type'} eq 'any' ) {
            if (exists($params{'where'}{'like'})) {
                my $like = $params{'where'}{'like'};
                my $like_op = {"-like" => "%${like}%"};
                $where{'-or'} = [pid => $like_op, firstname => $like_op, lastname => $like_op, email => $like_op];
            }
        }
    }

    if ( defined( $params{'orderby'} ) ) {
        $search{'-order_by'} = $params{'orderby'};
    }
    if ( defined( $params{'limit'} ) ) {
        $search{'-limit'} = $params{'limit'};
    }

    my ($status, $iter) = pf::dal::person->search(%search);

    if (is_error($status)) {
        return;
    }
    return @{$iter->all(undef) // []};
}

sub person_modify {
    my ( $pid, %data ) = @_;

    my $logger = get_logger();
    my ($status, $item) = pf::dal::person->find_or_create({%data, pid => $pid});
    if (is_error($status)) {
        return (0);
    }
    if ($status == $STATUS::CREATED) {
        $logger->warn(
            "modify of non-existent person $pid attempted - person added"
        );
        return (2);
    }
    $item->merge(\%data);
    my $new_pid = $item->pid;

    # compare pid case insensitively to prevent juser from not matching Juser
    if ( lc $pid ne lc $new_pid && person_exist($new_pid) ) {
        $logger->error(
            "modify of pid $pid to $new_pid conflicts with existing person");
        return (0);
    }
    $status = $item->save;
    if (is_error($status)) {
        return (0);
    }
    $logger->info("person $pid modified to $new_pid") if ($pid ne $new_pid);
    return (1);
}

sub person_nodes {
    my ($pid) = @_;
    my ($status, $iter) = pf::dal::node->search(
        -where => {
            pid => $pid,
        },
        -columns => [qw(mac pid notes regdate unregdate lastskip status user_agent computername device_class time_balance bandwidth_balance)],
        #To avoid join
        -from => pf::dal::node->table,
        -with_class => undef,
    );
    if (is_error($status)) {
        return;
    }

    return @{$iter->all // []};
}

=head2 person_unassign_nodes

unassign the nodes of a person

=cut

sub person_unassign_nodes {
    my ($pid) = @_;
    my ($status, $count) = pf::dal::node->update_items(
        -where => {
            pid => $pid,
        },
        -set => {
            pid => $default_pid
        }
    );
    if (is_error($status)) {
        return undef;
    }

    return $count;
}

sub person_security_events {
    my ($pid) = @_;
    my ($status, $iter) = pf::dal::security_event->search(
        -where => {
            pid => $pid,
        },
        -from => [-join => qw(security_event =>{security_event.mac=node.mac} node =>{security_event.security_event_id=class.security_event_id} class)],
        -order_by => {-desc => 'start_date'},
    );
    if (is_error($status)) {
        return;
    }

    return @{$iter->all // []};
}

=head2 persons_without_nodes

Get all the persons who are not the owner of at least one node.

=cut

sub persons_without_nodes {
    my ($status, $iter) = pf::dal::person->search(
        -from => [-join => qw(person =>{node.pid=person.pid} node)],
        -columns => ['person.pid'],
        -group_by => 'pid',
        -having => 'count(node.mac)=0',
    );
    if (is_error($status)) {
        return;
    }
    return @{ $iter->all(undef) // []};
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
            if ($expiration eq $ZERO_DATE) {
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

Copyright (C) 2005-2019 Inverse inc.

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
