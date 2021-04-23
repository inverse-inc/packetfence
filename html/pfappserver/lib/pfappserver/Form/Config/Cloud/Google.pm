package pfappserver::Form::Config::Cloud::Google;

=head1 NAME

pfappserver::Form::Config::Cloud::Google - Web form to add a Google service

=head1 DESCRIPTION

Form definition to create or update a Google service.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Cloud';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);

has_field 'username' =>
  (
   type => 'Text',
   label => 'Username',
   required => 1,
   messages => { required => 'Please specify the username for the Google cloud' },
  );

has_field 'port' =>
  (
   type => 'Port',
   label => 'Port of the service',
   tags => { after_element => \&help,
             help => 'If you use an alternative port, please specify' },
   default => 443,
  );
has_field 'type' =>
  (
   type => 'Hidden',
   default => 'Google',
  );

has_block definition =>
  (
   render_list => [ qw(id type username password port) ],
  );

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
