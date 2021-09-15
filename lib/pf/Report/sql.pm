package pf::Report::sql;

=head1 NAME

pf::Report::sql -

=head1 DESCRIPTION

pf::Report::sql

=cut

use strict;
use warnings;
use Moose;
extends qw(pf::Report);

has default_limit => (is => 'rw', isa => 'Str', default => 25);

has cursor_type => ( is => 'rw', isa => 'Str');

has cursor_field => ( is => 'rw', isa => 'Str');

has cursor_default => ( is => 'rw', isa => 'Str');

has sql => ( is => 'rw', isa => 'Str');

sub generate_sql_query {
    my ($self, %info) = @_;
    my $sql = $self->sql;
    return ($sql, $self->create_bind_type_sql(%info));
}
sub create_bind {
    my ($self, %infos) = @_;
    my $tenant_id = 1;
    my $cursor = $infos{cursor} // $self->cursor_default;
    my $limit = $infos{limit} // $self->default_limit // 25;
    return [$tenant_id, $cursor, $limit];
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
