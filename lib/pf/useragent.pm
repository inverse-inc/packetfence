package pf::useragent;

=head1 NAME

pf::useragent

=cut

=head1 DESCRIPTION

pf::useragent is the module for User-Agent data management for both nodes and violations enforcement.

=cut

use strict;
use warnings;

use HTTP::BrowserDetect;
use Log::Log4perl;
use Sort::Naturally;
use List::Util qw(first);

use constant USERAGENT => 'useragent';

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT = qw($useragent_db_prepared useragent_db_prepare);
    @EXPORT_OK = qw(
        view view_all add
        property_to_tid
        process_useragent
        node_useragent_view
        node_useragent_view_all
        node_useragent_count
        node_useragent_count_searchable
        node_useragent_view_all_searchable
        is_mobile
    );
}

use pf::config;
use pf::db;
use pf::violation;

our @useragent_data;
# created for faster lookups
our $property_to_tid = {};

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $useragent_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $useragent_statements = {};

=head1 SUBROUTINES

=over

=item useragent_db_prepare

Initialize database prepared statements

=cut

sub useragent_db_prepare {
    my $logger = Log::Log4perl::get_logger('pf::useragent');
    $logger->debug("Preparing pf::useragent database queries");

    $useragent_statements->{'node_useragent_exist_sql'} = get_db_handle()->prepare(qq[
        SELECT mac FROM node_useragent WHERE mac = ?
    ]);

    $useragent_statements->{'node_useragent_insert_sql'} = get_db_handle()->prepare(qq[
        INSERT INTO node_useragent (mac, os, browser, device, device_name, mobile)
        VALUES (?, ?, ?, ?, ?, ?)
    ]);

    $useragent_statements->{'node_useragent_update_sql'} = get_db_handle()->prepare(qq[
        UPDATE node_useragent
        SET os = ?, browser = ?, device = ?, device_name = ?, mobile = ?
        WHERE mac = ?
    ]);

    $useragent_statements->{'node_useragent_view_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, browser, os, device, device_name, mobile, n.user_agent
        FROM node_useragent LEFT JOIN node as n USING (mac)
        WHERE mac = ?
    ]);

    $useragent_statements->{'node_useragent_view_all_sql'} = get_db_handle()->prepare(qq[
        SELECT mac, browser, os, device, device_name, mobile, n.user_agent
        FROM node_useragent LEFT JOIN node as n USING (mac)
        ORDER BY n.regdate DESC
    ]);

    $useragent_db_prepared = 1;
}

=item node_useragent_exist

Returns true if node_useragent record exists undef or 0 otherwise.

=cut

sub node_useragent_exist {
    my ($mac) = @_;
    my $query = db_query_execute(USERAGENT, $useragent_statements, 'node_useragent_exist_sql', $mac) || return (0);
    my ($val) = $query->fetchrow_array();
    $query->finish();
    return ($val);
}

=item node_useragent_add

=cut

sub node_useragent_add {
    my ( $mac, $data ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::useragent');

    if ( node_useragent_exist($mac) ) {
        $logger->error("rejected attempt to add existing node-useragent entry for $mac");
        return (2);
    }

    db_query_execute(USERAGENT, $useragent_statements, 'node_useragent_insert_sql',
        $mac, $data->{'os'}, $data->{'browser'}, $data->{'device'}, $data->{'device_name'}, $data->{'mobile'}
    ) || return (0);

    $logger->debug("node-useragent record $mac added");
    return (1);
}

=item node_useragent_update

=cut

sub node_useragent_update {
    my ( $mac, $data ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::useragent');

    db_query_execute(USERAGENT, $useragent_statements, 'node_useragent_update_sql',
        $data->{'os'}, $data->{'browser'}, $data->{'device'}, $data->{'device_name'}, $data->{'mobile'}, $mac
    ) || return (0);

    $logger->debug("node-useragent record $mac updated");
    return (1);
}

=item update_node_useragent_record

=cut

sub update_node_useragent_record {
    my ($mac, $browserDetect) = @_;
    my $logger = Log::Log4perl::get_logger('pf::useragent');

    my $record = {
        'os' => $browserDetect->os_string() || undef,
        'browser' => $browserDetect->browser_string() || undef,
        'device_name' => $browserDetect->device_name() || undef,
    };

    if ($browserDetect->device()) {
        $record->{'device'} = $YES;
    } else {
        $record->{'device'} = $NO;
    }

    if ($browserDetect->mobile) {
        $record->{'mobile'} = $YES;
    } else {
        $record->{'mobile'} = $NO;
    }

    # is there already an entry for this node?
    if (node_useragent_exist($mac)) {
        node_useragent_update($mac, $record);
    } else {
        node_useragent_add($mac, $record);
    }

    return $TRUE;
}

=item node_useragent_view_all - view all node_useragent entries, returns an array of hashrefs

=cut

sub node_useragent_view_all {
    return db_data(USERAGENT, $useragent_statements, 'node_useragent_view_all_sql');
}

=item node_useragent_view - view a node_useragent entry, returns an hashref

=cut

sub node_useragent_view {
    my ($mac) = @_;
    my $query = db_query_execute(USERAGENT, $useragent_statements, 'node_useragent_view_sql', $mac);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
}

=item is_mobile

Is a MAC considered mobile based on its User-Agent

Return values:
  undef if we have no information on the browser.
  true if it's a mobile
  false otherwise

=cut

sub is_mobile {
    my ($mac) = @_;

    my $useragent_info = node_useragent_view($mac);
    return if (!defined($useragent_info) || !defined($useragent_info->{'mobile'}));

    if ($useragent_info->{'mobile'} eq $YES) {
        return $TRUE;
    }
    return $FALSE;
}

=item count

View a single useragent trigger

=cut

sub node_useragent_count_searchable {
    my ( %params ) = @_;
    _init() if (!@useragent_data);

    my $greper = _make_greper(\%params);
    my $count  =
        grep {&$greper}
        @useragent_data;
    return ($count);
}


sub _make_greper {
    my ($params) = (@_);
    my $greper = sub {1};
    if ( exists $params->{where} ) {
        my $where = $params->{where};
        if($where->{type} eq 'any' && $where->{like} ne '' ) {
            my $like = $where->{like};
            $greper = sub {my $obj = $_; first { my $data = $obj->{$_}; defined($data) && $data =~ /\Q$like\E/i} qw(id property description) };
        }
    }
    return $greper;
}

=item view

View a single useragent trigger

=cut

sub view {
    my ($tid) = @_;

    return if (!defined($tid));

    _init() if (!@useragent_data);

    foreach my $record (@useragent_data) {
        return $record if ($record->{'id'} == $tid);
    }

    return;
}

=item view_all

View all useragent triggers

=cut

sub view_all {
    my $logger = Log::Log4perl::get_logger('pf::useragent');

    _init() if (!@useragent_data);

    return @useragent_data;
}

=item node_useragent_view_all_searchable

View all useragent triggers

=cut

sub node_useragent_view_all_searchable {
    my $logger = Log::Log4perl::get_logger('pf::useragent');
    my ( %params ) = @_;
    _init() if (!@useragent_data);
    my $greper = _make_greper(\%params);
    my $sorter = _make_sorter(\%params);
    my @data  =
        sort $sorter
        grep {&$greper}
        @useragent_data;
    if(exists $params{limit}) {
        my ($start,$per_page) = $params{limit} =~ /(\d+)\s*,\s*(\d+)/;
        if(@data > $per_page) {
            my $end = ($start+$per_page - 1);
            if ($end > $#data) {
                $end = $#data;
            }
            @data = @data[$start ..  $end];
        }
    }
    return @data;
}

sub _make_sorter {
    my ($params) = @_;
    my $sorter = sub {ncmp ($a->{id}, $b->{id}) };
    if(exists $params->{orderby}) {
        my ($field,$order) = $params->{orderby} =~ /ORDER BY\s+(.*)\s+(.*)/;
        if($order eq 'desc') {
            $sorter = sub {ncmp ($b->{$field}, $a->{$field}) };
        }
        else {
            $sorter = sub {ncmp ($a->{$field}, $b->{$field}) };
        }
    }
    return $sorter;
}

=item add

Add a useragent trigger along with it's metadata

=cut

sub add {
    my ($trigger_id, $property, $description) = @_;

    # add to data in RAM
    push @useragent_data, {
        'id' => $trigger_id,
        'property' => $property,
        'description' => $description,
    };

    # add to fast lookup cache
    $property_to_tid->{$property} = $trigger_id;

    return $TRUE;
}

=item property_to_tid

Lookup the trigger ID for a given browser property

=cut

sub property_to_tid {
    my ($property) = @_;

    return if (!defined($property));

    _init() if (!@useragent_data);

    return if (!defined($property_to_tid->{$property}));

    return $property_to_tid->{$property};
}

=item _init

Initializes the User-Agent data structure. It's two things, one fast lookup hash for trigger ids:

  browser property => trigger id

and one array of hashes with everything:

  (
    id => trigger id
    property => browser property
    description => property description
  )

Be _really_ careful modifying this method so that the trigger IDs will stay the same!
We don't want our users to keep updating their conf/violations.conf file to track changing trigger IDs.

=cut

sub _init {
    my $logger = Log::Log4perl::get_logger('pf::useragent');

    # TODO this is very strongly coupled to HTTP::BrowserDetect's internals, we should aim to add a feature upstream
    my %triggers = (
        1 => \@HTTP::BrowserDetect::BROWSER_TESTS,
        100 => {'device' => 'Any device browser'},  # handled differently: it's a sub and not a property (hash element)
        101 => \%HTTP::BrowserDetect::DEVICE_TESTS,
        200 => \@HTTP::BrowserDetect::GAMING_TESTS,
        300 => \@HTTP::BrowserDetect::MISC_TESTS,
        400 => \@HTTP::BrowserDetect::OS_TESTS,
        500 => \@HTTP::BrowserDetect::WINDOWS_TESTS,
        600 => \@HTTP::BrowserDetect::MAC_TESTS,
        700 => \@HTTP::BrowserDetect::UNIX_TESTS,
        800 => \@HTTP::BrowserDetect::BSD_TESTS,
        900 => \@HTTP::BrowserDetect::IE_TESTS,
        1000 => \@HTTP::BrowserDetect::OPERA_TESTS,
        1100 => \@HTTP::BrowserDetect::AOL_TESTS,
        1200 => \@HTTP::BrowserDetect::NETSCAPE_TESTS,
        1300 => \@HTTP::BrowserDetect::FIREFOX_TESTS,
        1400 => \@HTTP::BrowserDetect::ENGINE_TESTS,
        1500 => \@HTTP::BrowserDetect::ROBOT_TESTS,
    );

    $property_to_tid = {};
    @useragent_data = ();

    # loop on all characteristics (ex: OS, Device, Browsers, etc.)
    foreach my $property_group_id (sort {$a <=> $b} keys %triggers) {

        my $id_idx = $property_group_id;
        my $properties = $triggers{$property_group_id};
        if (ref($properties) eq 'ARRAY') {

            # for arrays, we add the properties without a description
            foreach my $property (@{$properties}) {
                add($id_idx, $property);
                $id_idx++;
            }
        } elsif (ref($properties) eq 'HASH') {
            # for hashes, we add the properties with a description
            foreach my $property (keys %{$properties}) {
                add($id_idx, $property, ${$properties}{$property});
                $id_idx++;
            }
        }
    }

    $logger->info("Static User-Agent lookup data initialized");
    return $TRUE;
}

=item process_useragent

Updates the node_useragent information according to User-Agent string and fires appropriate violation triggers
based on User-Agent properties.

=cut

sub process_useragent {
    my ($mac, $useragent) = @_;
    my $logger = Log::Log4perl::get_logger('pf::useragent');

    my $browserDetect = HTTP::BrowserDetect->new($useragent);

    update_node_useragent_record($mac, $browserDetect);

    # report a violation for every browser property (ex: windows, firefox, android, etc.)
    foreach my $browser_property ($browserDetect->browser_properties()) {
        my $tid = property_to_tid($browser_property);
        $logger->debug("sending USERAGENT::$tid ($browser_property) trigger");
        violation_trigger( $mac, $tid, "USERAGENT" );
    }

    return $TRUE;
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
