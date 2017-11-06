package pf::cmd::pf::import::nodes;
=head1 NAME

pf::cmd::pf::import::nodes add documentation

=cut

=head1 DESCRIPTION

pf::cmd::pf::import::nodes

=head1 SYNOPSIS

pfcmd import nodes /path/to/file.csv [columns=<columns>] [default-role=<role>] [default-unregdate=<unregdate>] [default-voip=<yes|no>] [delimiter=<comma|semicolon|colon|tab>] [default-owner=<owner>]

Where:

 - /path/to/file.csv is the path to the file you want to import
 - [columns=<columns>] is the list of columns in the file in the right order comma delimited
    ex: columns=mac,category,unregdate
    Column names must match the column names of the node table
    When none are specified, it defaults to a single column containing the MAC address
 - [default-role=<role>] is the default role when none is defined via the import file.
    When none is specified, it defaults to node_import.category in pf.conf
 - [default-unregdate=<unregdate>] is the default unregistration date when none is defined via the import file
    When none is specified, it defaults to "2038-01-01 00:00:00"
    Ensure you quote properly, ex: default-unregdate="2038-01-01 00:00:00"
 - [default-voip=<yes|no>] is the default voip values when none is defined via the import file.
    When none is specified, it defaults to node_import.voip in pf.conf
 - [default-owner=<owner>] is the default owner when none is defined via the import file.
    When none is specified, it defaults to node_import.pid in pf.conf
 - [delimiter=<delimiter>] is the delimiter to use when splitting values
    Valid values are: "comma", "semicolon", "colon" or "tab"
    When none is specified, it defaults to "comma"

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use Role::Tiny::With;
use pf::constants::exit_code qw($EXIT_SUCCESS);
with 'pf::cmd::roles::show_parent_help';

=head2 parseArgs

Parse the arguments for this command

=cut

sub parseArgs {
    my ($self) = @_;

    my ( $file, @params ) = $self->args;

    require pf::config;

    my %params = (
        'columns'           => "mac",
        'default-role'      => "default",
        'default-unregdate' => "2038-01-01 00:00:00",
        'default-voip'      => "no",
        'default-owner'     => "default",
        'delimiter'         => "comma",
    );
    foreach my $param ( @params ) {
        my @data = split('=', $param);
        if ( exists($params{$data[0]}) ) {
            if ( length($data[1]) >= 1 ) {
                $params{$data[0]} = $data[1];
            }
            else {
                print STDERR "Invalid parameter value '$data[1]' for parameter '$data[0]'\n";
            }
        }
        else {
            print STDERR "Unknown parameter '$data[0]'\n";
        }
    }

    my @columns = map { { enabled => 1, name => $_ } } split(/\s*,\s*/, $params{columns});

    $self->{params} = {
        %params,
        filename => $file,
        columns => \@columns,
    };

    return 1;
}

=head2 _run

Run the import

=cut

sub _run {
    my ($self) = @_;
    use lib 'html/pfappserver/lib';
    require pfappserver::Model::Node;
    require pf::nodecategory;
    
    my $params = $self->{params};
    my ($status, $info) = pfappserver::Model::Node->importCSV(
        $params->{filename},
        {
            columns => $params->{columns},
            delimiter => $params->{delimiter},
            default_pid => $params->{"default-owner"},
            default_category_id => pf::nodecategory::nodecategory_view_by_name($params->{"default-role"})->{category_id},
            default_voip => $params->{"default-voip"},
        },
    );
    
    print "Import process complete. Imported $info->{count} and skipped $info->{skipped}\n";
    return $EXIT_SUCCESS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

