package pf::Authentication::Condition;

=head1 NAME

pf::Authentication::Condition

=head1 DESCRIPTION

=cut

use Moose;

use pf::Authentication::constants;

has 'attribute' => (isa => 'Str', is => 'rw', required => 1);
has 'operator' => (isa => 'Str', is => 'rw', required => 1);
has 'value' => (isa => 'Str', is => 'rw', required => 1);

sub matches {
    my ($self, $attr, $v) = @_;

    if ($self->{'attribute'} eq $attr) {
        if ($self->{'operator'} eq $Conditions::EQUALS) {
            if (defined $v && $self->{'value'} eq $v) {
                return 1;
            }
        }
        elsif ($self->{'operator'} eq $Conditions::CONTAINS) {
            if (defined $v && index($v, $self->{'value'}) >= 0) {
                return 1;
            }
        }
        elsif ($self->{'operator'} eq $Conditions::STARTS) {
            if (defined $v && index($v, $self->{'value'}) == 0) {
                return 1;
            }
        }
        elsif ($self->{'operator'} eq $Conditions::ENDS) {
            if (defined $v && ($v =~ m/\Q${$self}{value}\E$/)) {
                return 1;
            }
        }
    }

    return 0;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
