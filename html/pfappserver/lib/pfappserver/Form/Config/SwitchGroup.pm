package pfappserver::Form::Config::SwitchGroup;

=head1 NAME

pfappserver::Form::Config::Switch - Web form for a switch

=head1 DESCRIPTION

Form definition to create or update a network switch.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Switch';

## Definition

=head2 id

Override the field from switch to change the label

=cut

has_field 'id' =>
  (
   type => 'Text',
   label => 'Group name',
   required => 1,
   messages => { required => 'Please specify a group name' },
   apply => [ pfappserver::Base::Form::id_validator('group name') ]
  );

=head2 group

Overide the field from switch so a group cannot be specified

=cut

has_field 'group' =>
  (
   type => 'Hidden',
   value => '',
   default => '',
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
