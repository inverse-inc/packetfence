package pfappserver::Form::Config::Provisioning::servicenow;

=head1 NAME

pfappserver::Form::Config::Provisioning::servicenow - Web form for servicenow provisioner

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Provisioning';
with 'pfappserver::Base::Form::Role::Help';

has_field username => (
    type => 'Text',
    required => 1,
);

has_field password => (
    type => 'ObfuscatedText',
    required => 1,
);

has_field host => (
    type => 'Text',
    required => 1,
);

has_field table_for_mac => (
    type => 'Text',
    required => 1,
);

has_field table_for_agent => (
    type => 'Text',
    required => 1,
);

has_field 'protocol' =>
  (
   type => 'Select',
   options => [{ label => 'http', value => 'http' }, { label => 'https' , value => 'https' }],
   default => 'https',
  );

has_block definition =>
  (
   render_list => [ qw(id type description category oses username password protocol host table_for_mac table_for_agent) ],
  );

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
