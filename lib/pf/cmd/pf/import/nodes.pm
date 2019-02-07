package pf::cmd::pf::import::nodes;
=head1 NAME

pf::cmd::pf::import::nodes add documentation

=cut

=head1 DESCRIPTION

pf::cmd::pf::import::nodes

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use Role::Tiny::With;
use pf::constants qw($TRUE $FALSE);
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::file_paths qw($install_dir);
use pf::error qw(is_success);
with 'pf::cmd::roles::show_parent_help';

=head2 parseArgs

Parse the arguments for this command

=cut

sub parseArgs {
    my ($self) = @_;

    my ( $file, @params ) = $self->args;

    unless(defined($file)) {
        print STDERR "You must specify a file name\n";
        return $FALSE;
    }

    unless(-f $file) {
        print STDERR "File $file doesn't exist...\n";
        return $FALSE;
    }

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
        my ($name, $val) = split('=', $param);
        if ( exists($params{$name}) ) {
            if ( length($val) >= 1 ) {
                $params{$name} = $val;
            }
            else {
                print STDERR "Invalid parameter value '$val' for parameter '$name'\n";
            }
        }
        else {
            print STDERR "Unknown parameter '$name'\n";
        }
    }

    my @columns = map { { enabled => 1, name => $_ } } split(/\s*,\s*/, $params{columns});

    $self->{params} = {
        %params,
        filename => $file,
        columns => \@columns,
    };

    return $TRUE;
}

=head2 _run

Run the import

=cut

sub _run {
    my ($self) = @_;
    require pf::nodecategory;
    require pf::import;
    
    my $params = $self->{params};
    my ($status, $info) = pf::import::nodes(
        $params->{filename},
        {
            columns => $params->{columns},
            delimiter => $params->{delimiter},
            default_pid => $params->{"default-owner"},
            default_category_id => pf::nodecategory::nodecategory_view_by_name($params->{"default-role"})->{category_id},
            default_voip => $params->{"default-voip"},
            default_unregdate => $params->{"default-unregdate"},
        },
    );
    
    print "Import process complete. Imported $info->{count} and skipped $info->{skipped}\n";
    return is_success($status) ? $EXIT_SUCCESS : $EXIT_FAILURE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

