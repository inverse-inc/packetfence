package pf::import;

=head1 NAME

pf::import - module handling importation from pfcmd (and web admin)

=cut

=head1 DESCRIPTION

pf::import contains the functions necessary to manage all aspects
of bulk imports

=head1 DEVELOPER NOTES

Notice that this module doesn't export all its subs like our other modules do.
This is an attempt to shift our paradigm towards calling with package names
and avoid the double naming.

For ex: pf::import::nodes() instead of pf::import::import_nodes()

Remove this note when it will be no longer relevant. ;)

=cut

use strict;
use warnings;

use pf::log;
use Text::CSV;
use POSIX;

use pf::error;
use pf::constants;
use pf::config qw(%Config);
use pf::node;
use pf::nodecategory qw(nodecategory_lookup);
use pf::person;
use pf::util;

=head1 SUBROUTINES

=over

=item nodes

Handle bulk importation of nodes. They are automatically registered.

=cut

sub nodes {
    my ($file, $data, $user, $allowed_roles) = @_;
    my $logger = get_logger();

    my ($status, $message);
    my $filename = $data->{nodes_file_display_name} // $file;
    my $tmpfilename = $file;
    my $delimiter = $data->{delimiter};
    my $default_node_pid = $data->{default_pid};
    my $default_category_id = $data->{default_category_id};
    my $default_voip = $data->{default_voip};
    my $default_unregdate = $data->{default_unregdate};

    $logger->debug("CSV file import nodes from $tmpfilename ($filename, \"$delimiter\")");

    # Build hash table for columns order
    my $count = 0;
    my $skipped = 0;
    my %index = ();
    foreach my $column (@{$data->{columns}}) {
        if ($column->{enabled} || $column->{name} eq 'mac') {
            # Add checked columns and mandatory columns
            $index{$column->{name}} = $count;
            $count++;
        }
    }

    # Map delimiter to its actual character
    if ($delimiter eq 'comma') {
        $delimiter = ',';
    } elsif ($delimiter eq 'semicolon') {
        $delimiter = ';';
    } elsif ($delimiter eq 'colon') {
        $delimiter = ':';
    } elsif ($delimiter eq 'tab') {
        $delimiter = "\t";
    }

    # Read CSV file
    $count = 0;
    my $import_fh;
    my $has_pid = exists $index{'pid'};
    unless (open ($import_fh, "<", $tmpfilename)) {
        $logger->warn("Can't open CSV file $filename: $@");
        return  ($STATUS::INTERNAL_SERVER_ERROR, "Can't read CSV file.");
    }
    my $csv = Text::CSV->new({ binary => 1, sep_char => $delimiter });
    my $result;
    while (my $row = $csv->getline($import_fh)) {
        my ($pid, $mac, $node, %data, $result);
        $result = undef;
        if($has_pid) {
            $pid = $row->[$index{'pid'}] || undef;
            if ( $pid ) {
                if($pid !~ /$pf::person::PID_RE/) {
                    $logger->debug("Ignored invalid PID ($pid)");
                    next;
                }
                if(!person_exist($pid)) {
                    $logger->info("Adding non-existant person $pid");
                    person_add($pid);
                }
            }
        }

        $mac = $row->[$index{'mac'}] || undef;
        if (!$mac || !valid_mac($mac)) {
            $logger->debug("Ignored invalid MAC ($mac)");
            next;
        }

        $mac = clean_mac($mac);
        $pid ||= $default_node_pid || $default_pid;
        $node = node_view($mac);
        %data =
          (
           'mac'         => $mac,
           'pid'         => $pid,
           'category'    => $index{'category'}  ? $row->[$index{'category'}]  : undef,
           'category_id' => $index{'category'}  ? undef                       : $default_category_id,
           'unregdate'   => $index{'unregdate'} ? $row->[$index{'unregdate'}] : $default_unregdate,
           'voip'        => $index{'voip'}      ? $row->[$index{'voip'}]      : $default_voip,
           'notes'       => $index{'notes'}     ? $row->[$index{'notes'}]     : undef,
          );
        if (exists $index{'bypass_vlan'}) {
                $data{'bypass_vlan'} = $row->[$index{'bypass_vlan'}];
        }

        if (exists $index{'bypass_role'}) {
            $data{'bypass_role_id'} = nodecategory_lookup($row->[$index{'bypass_role'}]);
        }

        my $category = $data{category};
        $logger->info("Category " . ($category // "'undef'"));
        if ( defined($allowed_roles) && (defined $category && !exists $allowed_roles->{$category} ) ) {
            $logger->warn("Ignored $mac since category $category is not allowed for user");
            next;
        }

        if (!defined($node) || (ref($node) eq 'HASH' && $node->{'status'} ne $pf::node::STATUS_REGISTERED)) {
            $logger->debug("Register MAC $mac ($pid)");
            ($result, my $msg) = node_register($mac, $pid, %data);
        } else {
            $logger->debug("Modify already registered MAC $mac ($pid)");
            $result = node_modify($mac, %data);
            node_update_last_seen($mac);
        }

    } continue {
        if ($result) {
            $count++;
        } else {
            $skipped++;
        }
    }
    unless ($csv->eof) {
        $logger->warn("Problem with CSV file importation: " . $csv->error_diag());
        ($status, $message) = ($STATUS::INTERNAL_SERVER_ERROR, ["Problem with importation: [_1]" , $csv->error_diag()]);
    }
    else {
        ($status, $message) = ($STATUS::CREATED, { count => $count, skipped => $skipped });
    }
    close $import_fh;

    $logger->info("CSV file ($filename) import $count nodes, skip $skipped nodes");

    return ($status, $message);
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
