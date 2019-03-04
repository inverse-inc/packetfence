package pfconfig::namespaces::config::Survey;

=head1 NAME

pfconfig::namespaces::config::Survey

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Survey

This module creates the configuration hash associated to survey.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw(
    $survey_config_file
);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $survey_config_file;
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{ $self->{cfg} };

    for my $id (keys(%tmp_cfg)) {
        my $type = $tmp_cfg{$id}->{type};
        if(defined($type) && $type eq "Select") {
            $tmp_cfg{$id}->{choices} = [ split(/\n/, $tmp_cfg{$id}->{choices}) ];
        }
    }

    my $cfg = {};

    my @surveys = map { $_ !~ /[ ]+/ ? $_ : () } keys(%tmp_cfg);

    for my $survey (@surveys) {
        $cfg->{$survey} = $tmp_cfg{$survey};
        my $ordered = $cfg->{$survey}->{fields_order} = [ map { $_ =~ /^$survey field (.+)/ ? ($1) : () } @{$self->{ordered_sections}} ];
        $cfg->{$survey}->{fields} = { map { $_ => $tmp_cfg{"$survey field $_"} } @$ordered };
        $cfg->{$survey}->{data_fields} = { map { $_ =~ /^$survey data (.+)/ ? ($1 => $tmp_cfg{$_}) : () } @{$self->{ordered_sections}} };
    }

    return $cfg;
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


