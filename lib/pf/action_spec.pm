package pf::action_spec;

=head1 NAME

pf::action_spec -

=head1 DESCRIPTION

pf::action_spec

=cut

use strict;
use warnings;

sub parse_action_spec {
    my ($action_spec) = @_;
    unless ($action_spec =~ /^\s*([^:]+)\s*:\s*(.*)\s*$/) {
        return "Invalid action spec provided", undef;
    }

    return undef, { api_method => $1, api_parameters => $2};
}

sub eval_action_spec {
    my ($action_spec, $args) = @_;
    my ($err, $action) = parse_action_spec($action_spec);
    if ($err) {
        return $err, undef;
    }

    $action->{api_parameters} = eval_params($action->{api_parameters}, $args);
    return undef, $action;
}

sub eval_params {
    my ($action_params, $args) = @_;
    my @params = split(/\s*[,=]\s*/, $action_params);
    my @return;
    foreach my $param (@params) {
        $param =~ s/\$([A-Za-z0-9_]+)/$args->{$1} \/\/ '' /ge;
        push @return, $param;
    }
    return \@return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
