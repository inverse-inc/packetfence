package pf::dal::ctx::delete;

=head1 NAME

pf::dal::ctx::delete -

=head1 DESCRIPTION

pf::dal::ctx::delete

=cut

use strict;
use warnings;
use base qw(pf::dal::ctx::action);
use Class::XSAccessor {
    accessors => [qw(args)],
};

sub sql_bind {
    my ($self) = @_;
    my $dal = $self->dal;
    my $sqla = $dal->get_sql_abstract;
    my %args = @{$self->args};
    my $ignore        = delete $args{'-ignore'};
    my @args = $self->update_params_for_delete(%args);
    my ($stmt, @bind) = $sqla->delete(@args);
    if ($ignore) {
        my $s = $sqla->_sqlcase('delete ignore ');
        $stmt =~ s/delete /$s/ie;
    }

    return 200, $stmt, @bind;
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
