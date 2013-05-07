package pfappserver::Form::Authentication::Source;

=head1 NAME

pfappserver::Form::Authentication::Source - Common Web form for a user source

=head1 DESCRIPTION

Common form definition to create or update a user source. This class is intended
to be extended.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';

use pf::authentication;

has 'id' => ( is => 'ro' );

# Form fields
has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify an identifier for the source.' },
   apply => [ { check => qr/^\S+$/, message => 'The name must not contain spaces.' } ],
  );
has_field 'description' =>
  (
   type => 'Text',
   label => 'Description',
   required => 1,
  );
has_field 'rules' =>
  (
   type => 'Repeatable',
   num_when_empty => 0,
  );
has_field 'rules.id' =>
  (
   type => 'Hidden',
   widget_wrapper => 'None',
  );
has_field 'rules.description' =>
  (
   type => 'Text',
  );

=head2 validate

Make sure the source ID (name) is unique

=cut

sub validate {
    my $self = shift;

    if ($self->{id} && $self->{id} ne $self->value->{id} || !$self->{id}) {
        my $source = getAuthenticationSource($self->value->{id});
        if (defined $source) {
            $self->field('id')->add_error('This name is already taken.');
        }
    }
}

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

__PACKAGE__->meta->make_immutable;
1;
