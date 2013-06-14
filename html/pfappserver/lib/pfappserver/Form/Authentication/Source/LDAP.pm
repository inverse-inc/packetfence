package pfappserver::Form::Authentication::Source::LDAP;

=head1 NAME

pfappserver::Form::Authentication::Source::LDAP - Web form for a LDAP user source

=head1 DESCRIPTION

Form definition to create or update a LDAP user source.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Authentication::Source';
with 'pfappserver::Base::Form::Role::Help';

# Form fields
has_field 'host' =>
  (
   type => 'Text',
   label => 'Host',
   element_class => ['input-small'],
   element_attr => {'placeholder' => '127.0.0.1'},
  );
has_field 'port' =>
  (
   type => 'PosInteger',
   label => 'Port',
   element_class => ['input-mini'],
   element_attr => {'placeholder' => '389'},
  );
has_field 'encryption' =>
  (
   type => 'Select',
   label => 'Encryption',
   options => 
   [
    { value => 'none', label => 'None' },
    { value => 'ssl', label => 'SSL' },
    { value => 'starttls', label => 'Start TLS' },
   ],
   required => 1,
   element_class => ['input-small'],
  );
has_field 'basedn' =>
  (
   type => 'Text',
   label => 'Base DN',
   required => 1,
   element_class => ['span10'],
  );
has_field 'scope' =>
  (
   type => 'Select',
   label => 'Scope',
   required => 1,
   options =>
   [
    { value => 'base', label => 'Base Object' },
    { value => 'one', label => 'One-level' },
    { value => 'sub', label => 'Subtree' },
    { value => 'children', label => 'Children' },
   ],
  );
has_field 'usernameattribute' =>
  (
   type => 'Text',
   label => 'Username Attribute',
   required => 1,
  );
has_field 'binddn' =>
  (
   type => 'Text',
   label => 'Bind DN',
   element_class => ['span10'],
   tags => { after_element => \&help,
             help => 'Leave this field empty if you want to perform an anonymous bind.' },
  );
has_field 'password' =>
  (
   type => 'Password',
   label => 'Password',
  );

=head2 validate

Make sure a password is specified when a bind DN is specified.

=cut

sub validate {
    my $self = shift;

    $self->SUPER::validate();

    if ($self->value->{binddn}) {
        unless ($self->value->{password}) {
            $self->field('password')->add_error('Please specify a password.');
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
