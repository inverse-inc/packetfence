package pfappserver::Form::Field::RE2;

=head1 NAME

pfappserver::Form::Field::RE2 - A RE2 regex field

=head1 DESCRIPTION

This field extends the default Text field and checks if the input value is an valid RE2 regex

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Text';

use pf::util;
use namespace::autoclean;


our $class_messages = {
    'regex' => 'It must be a valid RE2 regex',
};

=head2 get_class_messages

Overridden get_class_messages

=cut

sub get_class_messages {
    my $self = shift;
    return {
       %{ $self->next::method },
       %$class_messages,
    }
}

apply
  (
   [
    {
     check => sub {
         use re::engine::RE2 -strict => 1;
         my ( $value, $field ) = @_;
         return eval { qr/$value/ };
     },
     message => sub {
         my ( $value, $field ) = @_;
         return $field->get_message('regex');
     },
    }
   ]
  );

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
