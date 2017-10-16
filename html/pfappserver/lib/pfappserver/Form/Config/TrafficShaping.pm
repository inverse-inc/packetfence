package pfappserver::Form::Config::TrafficShaping;

=head1 NAME

pfappserver::Form::Config::TrafficShaping - Web form for an admin role

=head1 DESCRIPTION

Form definition to create or update an admin role

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::log;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Role',
   required => 1,
   messages => { required => 'The role to apply traffic shaping' },
  );
has_field 'upload' =>
  (
   type => 'Text',
   required => 1,
   messages => { required => 'Upload is required.' },
  );
has_field 'download' =>
  (
   type => 'Text',
   required => 1,
   messages => { required => 'Download is required.' },
  );

has_block  definition =>
  (
    render_list => [qw(upload download)],
  );

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
