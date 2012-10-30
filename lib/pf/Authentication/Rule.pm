=item

=cut
package pf::Authentication::Rule;
use Moose;

use constant {
        ANY => "any",
        ALL => "all",
      };

has 'id' => (isa => 'Str', is => 'rw', required => 1);
has 'description' => (isa => 'Str', is => 'rw', required => 0);
has 'match' => (isa => 'Str', is => 'rw', required => 1);
has 'actions' => (isa => 'ArrayRef', is => 'rw', required => 0);
has 'conditions' => (isa => 'ArrayRef', is => 'rw', required => 0);

sub add_action {
  my ($self, $action) = @_;
  push(@{$self->{'actions'}}, $action);
}

sub add_condition {
  my ($self, $condition) = @_;
  push(@{$self->{'conditions'}}, $condition);
}

=back

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
