package pf::trigger;

=head1 NAME

pf::trigger - module to manage the triggers related to the violations or
the Nessus scans (if enabled).

=cut

=head1 DESCRIPTION

pf::trigger contains the functions necessary to manage the different 
triggers related to the violations or the Nessus scans.

=head1 CONFIGURATION AND ENVIRONMENT

Read the F<pf.conf> configuration file.

=cut

use strict;
use warnings;
use Log::Log4perl;

use constant TRIGGER => 'trigger';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        trigger_db_prepare
        $trigger_db_prepared
        
        trigger_view
        trigger_view_enable
        trigger_view_all
        trigger_delete_all
        trigger_add
        trigger_view_type
        trigger_view_tid
        parse_triggers
    );
}

use pf::accounting qw($ACCOUNTING_TRIGGER_RE);
use pf::config;
use pf::db;
use pf::util;
use pf::violation qw(violation_trigger violation_add);
use pf::iplog qw(ip2mac);

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $trigger_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $trigger_statements = {};

=head1 SUBROUTINES

This list is incomplete.
        
=over   
        
=cut    

sub trigger_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::trigger');
    $logger->debug("Preparing pf::trigger database queries");

    $trigger_statements->{'trigger_desc_sql'} = get_db_handle()->prepare(qq [ desc `trigger` ]);

    $trigger_statements->{'trigger_view_sql'} = get_db_handle()->prepare(
        qq[ select tid_start,tid_end,class.vid,type,description from `trigger`,class where class.vid=`trigger`.vid and tid_start<=? and tid_end>=? and type=?]);

    $trigger_statements->{'trigger_view_enable_sql'} = get_db_handle()->prepare(
        qq[ select tid_start,tid_end,class.vid,type,whitelisted_categories from `trigger`,class where class.vid=`trigger`.vid and tid_start<=? and tid_end>=? and type=? and enabled="Y" ]
    );

    $trigger_statements->{'trigger_view_vid_sql'} = get_db_handle()->prepare(
        qq[ select tid_start,tid_end,class.vid,description from `trigger`,class where class.vid=`trigger`.vid and class.vid=?]);

    $trigger_statements->{'trigger_view_tid_sql'} = get_db_handle()->prepare(
        qq[ select tid_start,tid_end,class.vid,type,description from `trigger`,class where class.vid=`trigger`.vid and tid_start<=? and tid_end>=? ]);

    $trigger_statements->{'trigger_view_all_sql'} = get_db_handle()->prepare(
        qq[ select tid_start,tid_end,class.vid,type,description from `trigger`,class where class.vid=`trigger`.vid ]);

    $trigger_statements->{'trigger_view_type_sql'} = get_db_handle()->prepare(
        qq[ select tid_start,tid_end,class.vid,type,description from `trigger`,class where class.vid=`trigger`.vid and type=?]);

    $trigger_statements->{'trigger_exist_sql'} = get_db_handle()->prepare(
        qq [ select vid,tid_start,tid_end,type,whitelisted_categories from `trigger` where vid=? and tid_start<=? and tid_end>=? and type=? and whitelisted_categories=? ]
   );

    $trigger_statements->{'trigger_add_sql'} = get_db_handle()->prepare(
        qq [ insert into `trigger`(vid,tid_start,tid_end,type,whitelisted_categories) values(?,?,?,?,?) ]
    );

    $trigger_statements->{'trigger_delete_vid_sql'} = get_db_handle()->prepare(qq [ delete from `trigger` where vid=? ]);

    $trigger_statements->{'trigger_delete_all_sql'} = get_db_handle()->prepare(qq [ delete from `trigger` ]);

    $trigger_db_prepared = 1;
    return 1;
}

sub trigger_desc {
    return db_data(TRIGGER, $trigger_statements, 'trigger_desc_sql');
}

sub trigger_view {
    my ( $tid, %type ) = @_;
    return db_data(TRIGGER, $trigger_statements, 'trigger_view_sql', $tid, $tid, $type{type});
}

sub trigger_view_enable {
    my ( $tid, $type ) = @_;
    return db_data(TRIGGER, $trigger_statements, 'trigger_view_enable_sql', $tid, $tid, $type);
}

sub trigger_view_vid {
    my ($vid) = @_;
    return db_data(TRIGGER, $trigger_statements, 'trigger_view_vid_sql', $vid);
}

sub trigger_view_tid {
    my ($tid) = @_;
    return db_data(TRIGGER, $trigger_statements, 'trigger_view_tid_sql', $tid, $tid);
}

sub trigger_view_all {
    return db_data(TRIGGER, $trigger_statements, 'trigger_view_all_sql');
}

sub trigger_view_type {
    my ($type) = @_;
    return db_data(TRIGGER, $trigger_statements, 'trigger_view_type_sql', $type);
}

sub trigger_delete_vid {
    my ($vid) = @_;
    my $logger = Log::Log4perl::get_logger('pf::trigger');

    db_query_execute(TRIGGER, $trigger_statements, 'trigger_delete_vid_sql', $vid) || return (0);
    $logger->debug("triggers vid $vid deleted");
    return (1);
}

sub trigger_delete_all {
    my $logger = Log::Log4perl::get_logger('pf::trigger');
    db_query_execute(TRIGGER, $trigger_statements, 'trigger_delete_all_sql') || return (0);
    $logger->debug("All triggers deleted");
    return (1);
}

sub trigger_exist {
    my ($vid, $tid_start, $tid_end, $type, $whitelisted_categories) = @_;

    my $query = db_query_execute(TRIGGER, $trigger_statements, 'trigger_exist_sql', 
        $vid, $tid_start, $tid_end, $type, $whitelisted_categories)
        || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

#
# clean input parameters and add to trigger table
#
sub trigger_add {
    my ($vid, $tid_start, $tid_end, $type, $whitelisted_categories) = @_;
    my $logger = Log::Log4perl::get_logger('pf::trigger');
    if ( trigger_exist( $vid, $tid_start, $tid_end, $type, $whitelisted_categories) ) {
        $logger->error(
            "attempt to add existing trigger $tid_start $tid_end [$type]");
        return (2);
    }
    db_query_execute(TRIGGER, $trigger_statements, 'trigger_add_sql', 
        $vid, $tid_start, $tid_end, $type, $whitelisted_categories)
        || return (0);
    $logger->debug("trigger $tid_start $tid_end added");
    return (1);
}

sub parse_triggers {
    my ($violation_triggers) = @_;

    my $triggers_ref = [];
    foreach my $trigger ( split( /\s*,\s*/, $violation_triggers ) ) {   

        # TODO we should refactor this into objects where trigger types provide their own matchers
        # at first, we are liberal in what we accept
        die("Invalid trigger id: $trigger") if ($trigger !~ /^\w+::[^:]+$/);

        my ( $type, $tid ) = split( /::/, $trigger );
        $type = lc($type);
        $tid =~ s/\s+$//; # trim trailing whitespace

        # make sure trigger is a valid trigger type
        # TODO refactor into an ListUtil test or an hash lookup (see Perl Best Practices)
        if ( !grep( { lc($_) eq $type } @VALID_TRIGGER_TYPES ) ) {
            die("Invalid trigger type ($type)");
        }

        # special accouting only trigger parser
        if ($type eq 'accounting') {
            die("Invalid accounting trigger id: $trigger") if ($tid !~ /^$ACCOUNTING_TRIGGER_RE$/);
        }
        # usual trigger allowing digits, ranges and dots with optional trailing whitespace
        else {
            die("Invalid trigger id: $trigger") if ($trigger !~ /^\w+::[\d\.-]+\s*$/);
        }

        # process range
        if ( $tid =~ /(\d+)-(\d+)/ ) {
            if ( $2 > $1 ) {
                push @$triggers_ref, [ $1, $2, $type ];
            } else {
                die("Invalid trigger range ($1 - $2)");
            }
        } else {
            push @$triggers_ref, [ $tid, $tid, $type ];
        }
    }
    return $triggers_ref;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
