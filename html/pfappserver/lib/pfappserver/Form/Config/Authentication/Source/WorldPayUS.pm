package pfappserver::Form::Config::Authentication::Source::WorldPayUS;

=head1 NAME

pfappserver::Form::Config:::Authentication::Source::WorldPayUS

=cut

=head1 DESCRIPTION

pfappserver::Form::Config:::Authentication::Source::WorldPayUS

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
use pf::Authentication::Source::WorldPayUSSource;
extends 'pfappserver::Form::Config::Authentication::Source::Billing';
with 'pfappserver::Base::Form::Role::Help';

has_field 'domains' =>
  (
   type => 'Text',
   label => 'Authorized domains',
   required => 1,
   default => pf::Authentication::Source::WorldPayUSSource->meta->get_attribute('domains')->default,
   element_attr => {'placeholder' => pf::Authentication::Source::WorldPayUSSource->meta->get_attribute('domains')->default},
   element_class => ['input-xlarge'],
   tags => { after_element => \&help,
             help => 'Comma separated list of domains that should be resolved with the correct IP addresses.' },
  );

has_field base_uri =>
  (
   type => 'Text',
   required => 1,
  );

has_field form_id =>
  (
   type => 'Text',
   required => 1,
  );

has_field session_id =>
  (
   type => 'Text',
   required => 1,
  );

has_field des_key =>
  (
   type => 'Text',
   required => 1,
  );

has_block definition => (
    render_list => [qw(base_uri form_id session_id des_key domains create_local_account local_account_logins)]
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

1;
