package pf::dal::ctx::action;

=head1 NAME

pf::dal::ctx::action -

=head1 DESCRIPTION

pf::dal::ctx::action

=cut

use strict;
use warnings;
use Class::XSAccessor {
    accessors => [qw(dal)],
};

=head2 new

Create a new pf::dal::ctx::upsert object

=cut

sub new {
    my ($proto, $args) = @_;
    my $class = ref($proto) || $proto;
    return bless {%$args}, $class;
}

sub cacheable { 0 }

sub process {
    my ($self, $status, $sth) = @_;
    return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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
