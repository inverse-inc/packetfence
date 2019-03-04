package pfconfig::namespaces::config::Report;

=head1 NAME

pfconfig::namespaces::config::Report

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Report

This module creates the configuration hash associated to report.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw(
    $report_config_file
    $report_default_config_file
);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file}              = $report_config_file;
    $self->{expandable_params} = [ qw(searches columns order_fields base_conditions person_fields node_fields) ];
    
    my $defaults = pf::IniFiles->new( -file => $report_default_config_file );
    $self->{added_params}->{'-import'} = $defaults;
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{ $self->{cfg} };

    foreach my $key ( keys %tmp_cfg ) {
        $self->cleanup_after_read( $key, $tmp_cfg{$key} );
        my @formatted_searches;
        foreach my $search (@{$tmp_cfg{$key}{searches}}) {
            my @pieces = split(/\s*\:\s*/, $search);
            push @formatted_searches, {type => $pieces[0], display => $pieces[1], field => $pieces[2]};
        }
        $tmp_cfg{$key}{searches} = \@formatted_searches;

        my @formatted_base_conditions;
        foreach my $condition (@{$tmp_cfg{$key}{base_conditions}}) {
            my @pieces = split(/\s*\:\s*/, $condition);
            push @formatted_base_conditions, {field => $pieces[0], operator => $pieces[1], value => $pieces[2]};
        }

        $tmp_cfg{$key}{base_conditions} = \@formatted_base_conditions;
        $tmp_cfg{$key}{searches} = \@formatted_searches;
        $tmp_cfg{$key}{joins} //= "";
        $tmp_cfg{$key}{joins} = [ split("\n", $tmp_cfg{$key}{joins}) ];
    }

    return \%tmp_cfg;

}

sub cleanup_after_read {
    my ( $self, $id, $item ) = @_;
    # By default expand_list doesn't expand undef values, in this case we want it so we define an empty value when undef
    foreach my $param (@{$self->{expandable_params}}) {
        $item->{$param} //= "";
    }
    $self->expand_list( $item, @{$self->{expandable_params}} );
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:


