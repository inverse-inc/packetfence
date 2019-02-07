package pfappserver::Form::Config::Pfdetect;

=head1 NAME

pfappserver::Form::Config::Pfdetect - Web form for a pfdetect detector

=head1 DESCRIPTION

Form definition to create or update a pfdetect detector.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Detector',
   required => 1,
   messages => { required => 'Please specify a detector id' },
   apply => [ pfappserver::Base::Form::id_validator('detector id') ]
  );

=head2 status

status

=cut

has_field 'status' => (
    type            => 'Toggle',
    label           => 'Enabled',
    checkbox_value  => 'enabled',
    unchecked_value => 'disabled',
    default => 'enabled',
);

has_field 'path' =>
  (
   type => 'Text',
   label => 'Alert pipe',
   required => 1,
   messages => { required => 'Please specify an alert pipe' },
  );

has_field 'type' =>
  (
   type => 'Hidden',
   required => 1,
  );

has_block definition =>
  (
   render_list => [ qw(id type status path) ],
  );

=over

=back

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
