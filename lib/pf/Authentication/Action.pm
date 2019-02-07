package pf::Authentication::Action;

=head1 NAME

pf::Authentication::Action

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;
use Moose;

use List::MoreUtils qw(any);
use List::Util qw(first);

has 'type'  => (isa => 'Str', is => 'rw', required => 1);
has 'class' => (isa => 'Str', is => 'rw', required => 1);
has 'value' => (isa => 'Str', is => 'rw', required => 0);

=head2 BUILDARGS

=cut

sub BUILDARGS {
    my ($class, @args) = @_;
    my $argshash = $class->SUPER::BUILDARGS(@args);
    if (exists $argshash->{type} && !exists $argshash->{class}) {
        $argshash->{class} = $class->getRuleClassForAction($argshash->{type});
    }
    return $argshash;
}

=head2 getRuleClassForAction

Returns the rule class for an action

=cut

sub getRuleClassForAction {
    my ( $self, $action ) = @_;
    return exists $Actions::ACTION_CLASS_TO_TYPE{$action} ? $Actions::ACTION_CLASS_TO_TYPE{$action} : $Rules::AUTH;
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
