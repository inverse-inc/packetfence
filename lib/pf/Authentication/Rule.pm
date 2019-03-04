package pf::Authentication::Rule;

=head1 NAME

pf::Authentication::Rule

=head1 DESCRIPTION

=cut

use Moose;

use pf::Authentication::constants;

has 'id' => (isa => 'Str', is => 'rw', required => 1);
has 'class' => (isa => 'Str', is => 'rw', default => $Rules::AUTH);
has 'description' => (isa => 'Str', is => 'rw', required => 0);
has 'match' => (isa => 'Maybe[Str]', is => 'rw', default => $Rules::ANY);
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

sub is_fallback {
  my $self = shift;

  if (scalar @{$self->{'conditions'}} == 0 &&
      scalar @{$self->{'actions'}} > 0)
    {
      return 1;
    }

  return 0;
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
