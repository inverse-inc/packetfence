package pf::class;

=head1 NAME

pf::class - module to manage the violation classes.

=cut

=head1 DESCRIPTION

pf::class contains the functions necessary to manage the violation classes.

=cut

use strict;
use warnings;
use Log::Log4perl;

use constant CLASS => 'class';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        class_db_prepare
        $class_db_prepared

        class_view       class_view_all
        class_trappable  class_view_actions 
        class_add        class_delete 
        class_merge
    );
}

use pf::action;
use pf::db;

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $class_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $class_statements = {};

sub class_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::class');
    $logger->debug("Preparing pf::class database queries");

    $class_statements->{'class_view_sql'} = get_db_handle()->prepare(
        qq [ select class.vid,class.description,class.auto_enable,class.max_enables,class.grace_period,class.window,class.vclose,class.priority,class.template,class.max_enable_url,class.redirect_url,class.button_text,class.enabled,class.vlan,group_concat(action.action order by action.action asc) as action from class left join action on class.vid=action.vid where class.vid=? GROUP BY class.vid,class.description,class.auto_enable,class.max_enables,class.grace_period,class.priority,class.template,class.max_enable_url,class.redirect_url,class.button_text,class.enabled]);

    $class_statements->{'class_view_all_sql'} = get_db_handle()->prepare(
        qq [ select class.vid,class.description,class.auto_enable,class.max_enables,class.grace_period,class.window,class.vclose,class.priority,class.template,class.max_enable_url,class.redirect_url,class.button_text,class.enabled,class.vlan,group_concat(action.action order by action.action asc) as action from class left join action on class.vid=action.vid GROUP BY class.vid,class.description,class.auto_enable,class.max_enables,class.grace_period,class.priority,class.template,class.max_enable_url,class.redirect_url,class.button_text,class.enabled]);

    $class_statements->{'class_view_actions_sql'} = get_db_handle()->prepare(qq [ select vid,action from action where vid=? ]);

    $class_statements->{'class_exist_sql'} = get_db_handle()->prepare(qq [ select vid from class where vid=? ]);

    $class_statements->{'class_delete_sql'} = get_db_handle()->prepare(qq [ delete from class where vid=? ]);

    $class_statements->{'class_add_sql'} = get_db_handle()->prepare(
        qq [ insert into class(vid,description,auto_enable,max_enables,grace_period,window,vclose,priority,template,max_enable_url,redirect_url,button_text,enabled,vlan) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?) ]);

    $class_statements->{'class_modify_sql'} = get_db_handle()->prepare(
        qq [ update class set description=?,auto_enable=?,max_enables=?,grace_period=?,window=?,vclose=?,priority=?,template=?,max_enable_url=?,redirect_url=?,button_text=?,enabled=?,vlan=? where vid=? ]);

    $class_statements->{'class_cleanup_sql'} = get_db_handle()->prepare(
        qq [ delete from class where vid not in (?) and vid < 1200000 and vid > 1200100 ]);

    $class_statements->{'class_trappable_sql'} = get_db_handle()->prepare(
        qq [select c.vid,c.description,c.auto_enable,c.max_enables,c.grace_period,c.window,c.vclose,c.priority,c.template,c.max_enable_url,c.redirect_url,c.button_text,c.enabled,c.vlan from class c left join action a on c.vid=a.vid where a.action="trap" ]);

    $class_db_prepared = 1;
}

sub class_exist {
    my ($id) = @_;

    my $query = db_query_execute(CLASS, $class_statements, 'class_exist_sql', $id) || return (0);
    my ($val) = $query->fetchrow_hashref();
    $query->finish();
    return ($val);
}

sub class_view {
    my ($id) = @_;

    my $query = db_query_execute(CLASS, $class_statements, 'class_view_sql', $id) || return (0);
    my ($val) = $query->fetchrow_hashref();
    $query->finish();
    return ($val);
}

sub class_view_all {
    return db_data(CLASS, $class_statements, 'class_view_all_sql');
}

sub class_trappable {
    return db_data(CLASS, $class_statements, 'class_trappable_sql');
}

sub class_view_actions {
    my ($id) = @_;
    return db_data(CLASS, $class_statements, 'class_view_actions_sql', $id);
}

sub class_add {
    my $id = $_[0];
    my $logger = Log::Log4perl::get_logger('pf::class');
    if ( class_exist($id) ) {
        $logger->warn("attempt to add existing class $id");
        return (2);
    }
    db_query_execute(CLASS, $class_statements, 'class_add_sql', @_) || return (0);
    $logger->debug("class $id added");
    return (1);
}

sub class_delete {
    my ($id) = @_;
    my $logger = Log::Log4perl::get_logger('pf::class');
    db_query_execute(CLASS, $class_statements, 'class_delete_sql', $id) || return (0);
    $logger->debug("class $id deleted");
    return (1);
}

sub class_cleanup {
    my $logger = Log::Log4perl::get_logger('pf::class');
    db_query_execute(CLASS, $class_statements, 'class_cleanup_sql') || return (0);
    $logger->debug("class cleanup completed");
    return (1);
}

sub class_modify {
    my $id = shift(@_);
    my $logger = Log::Log4perl::get_logger('pf::class');
    push( @_, $id );
    if ( class_exist($id) ) {
        $logger->debug("modify existing existing class $id");
    }
    db_query_execute(CLASS, $class_statements, 'class_modify_sql', @_) || return (0);
    $logger->debug("class $id modified");
    return (1);
}

sub class_merge {
    my $id       = shift(@_);
    my $triggers = pop(@_);
    my $actions  = pop(@_);
    my $whitelisted_categories = pop(@_);
    my $logger   = Log::Log4perl::get_logger('pf::class');

    # delete existing violation actions
    if ( !pf::action::action_delete_all($id) ) {
        $logger->error("error deleting actions for class $id");
        return (0);
    }

    unshift( @_, $id );

    #Check for violations
    if ( class_exist($id) ) {
        class_modify(@_);
    } else {

        #insert violation class
        class_add(@_);
    }

    # add violation actions
    foreach my $action ( split( /\s*,\s*/, $actions ) ) {
        pf::action::action_add( $id, $action );
    }

    #Add scan table id's -> violation class maps
    if ( scalar( @{$triggers} ) > 0 ) {
        require pf::trigger;
        foreach my $array ( @{$triggers} ) {
            my ( $tid_start, $tid_end, $type ) = @{$array};
            pf::trigger::trigger_add($id, $tid_start, $tid_end, $type, $whitelisted_categories);
        }
    }
}

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
