package pfappserver::Form::Config::EventLogger;

=head1 NAME

pfappserver::Form::Config::EventLogger - Web form for a event logger.

=head1 DESCRIPTION

Form definition to create or update a event logger.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';
use pf::constants::eventLogger;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   required => 1,
  );
has_field 'description' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'type' =>
  (
   type => 'Hidden',
   required => 1,
  );

has_field namespaces => (
    type    => 'Select',
    options => [
        map { { label => $_, value => $_ } }
          @pf::constants::eventLogger::Namespaces
    ],
    multiple => 1,
);

=head2 default_type

Returns the default type of the Provisioning

=cut

sub default_type {
    my ($field) = @_;
    my $type = ref($field->form);
    $type =~ s/^pfappserver::Form::Config::EventLogger:://;
    return $type;
}

=head2 Methods

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
