package pfappserver::Form::Field::CIDR;

=head1 NAME

pfappserver::Form::Field::CIDR - IPv4 CIDR input field

=head1 DESCRIPTION

This field extends the default Text field and checks that the input
value is a valid IPv4 network in CIDR notation (e.g. 192.168.1.0/24).
The prefix length is mandatory and must be between 0 and 32.

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Text';

use pf::util;
use namespace::autoclean;

# If the field value matches one of the values defined in "accept", the field will pass validation.
# Otherwise, the field value must be a valid IPv4 address in CIDR notation.
has 'accept' => ( is => 'rw', isa => 'ArrayRef' );

our $class_messages = {
    'cidr' => 'Value must be an IPv4 address in CIDR notation (e.g. 192.168.1.0/24)',
};

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
         my ( $value, $field ) = @_;
         return 1 if ($field->accept && grep { $_ eq $value } @{$field->accept});
         my ( $ip, $prefix, $extra ) = split( m!/!, $value, 3 );
         return 0 if defined $extra;                    # only one slash allowed
         return 0 unless defined $prefix
             && $prefix =~ /^\d+$/ && $prefix >= 0 && $prefix <= 32;
         # 0.0.0.0/x is a valid network (e.g. the "any" CIDR) even though
         # valid_ip() rejects the all-zeros address as a host IP.
         return 1 if $ip eq '0.0.0.0';
         return valid_ip( $ip );
     },
     message => sub {
         my ( $value, $field ) = @_;
         return $field->get_message('cidr');
     },
    }
   ]
  );

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
