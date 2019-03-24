package pfappserver::Form::Config::Scan::Nessus;

=head1 NAME

pfappserver::Form::Config::Scan::Nessus - Web form to add a Nessus Scan Engine

=head1 DESCRIPTION

Form definition to create or update a Nessus Scan Engine.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Scan';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);
#For Input Validation/Sanitization
use Input::Validation;

has_field 'ip' =>
  (
   type => 'Text',
   label => 'Hostname or IP Address',
   required => 1,
   messages => { required => 'Please specify the hostname or IP of the scan engine' },
  );

has_field 'port' =>
  (
   type => 'Port',
   label => 'Port of the service',
   tags => { after_element => \&help,
             help => 'If you use an alternative port, please specify' },
   default => 8834,
  );
has_field 'type' =>
  (
   type => 'Hidden',
  );

has_block definition =>
  (
   render_list => [ qw(id ip type username password port nessus_clientpolicy categories oses duration pre_registration registration post_registration) ],
  );

has_field 'nessus_clientpolicy' =>
  (
   type => 'Text',
   label => 'Nessus client policy',
   tags => { after_element => \&help,
             help => 'Name of the policy to use on the nessus server' },
  );

  sub validate_ip {
    my ( $self, $field ) = @_;
    form_field_validation('hostname||ip', 1 , $field);
  }


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
