package pf::tenant;

=head1 NAME

pf::tenant -

=cut

=head1 DESCRIPTION

pf::tenant

=cut

use strict;
use warnings;
use pf::error qw(is_error is_success);
use pf::constants qw($TRUE $FALSE);
use pf::dal::tenant;
use pf::dal::person;

use Exporter qw(import);

our @EXPORT_OK = qw(
    tenant_add
    tenant_view_by_name
);


=head2 tenant_add

tenant_add

=cut

sub tenant_add {
    my ($data) = @_;
    my $status = pf::dal::tenant->create($data);
    return is_success($status);
}

=head2 tenant_view_by_name

tenant_view_by_name

=cut

sub tenant_view_by_name {
    my ($name) = @_;
    my ($status, $iter) = pf::dal::tenant->search(
        -where => {
            name => $name,
        },
        -limit => 1,
        -with_class => undef,
    );
    if (is_error($status)) {
        return undef;
    }
    my $item = $iter->next;
    return $item;
}



=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

