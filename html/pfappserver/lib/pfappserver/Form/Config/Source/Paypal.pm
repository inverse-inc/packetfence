package pfappserver::Form::Config::Source::Paypal;

=head1 NAME

pfappserver::Form::Config:::Authentication::Source::Paypal

=cut

=head1 DESCRIPTION

Form definition to create or update a Paypal authentication source.

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
use pf::Authentication::Source::PaypalSource;
extends 'pfappserver::Form::Config::Source::Billing';
with 'pfappserver::Base::Form::Role::Help';

has_field identity_token =>
  (
   type => 'Text',
   required => 1,
  );

has_field cert_id =>
  (
   type => 'Text',
   required => 1,
  );

has_field cert_file =>
  (
   type => 'Path',
   element_class => ['input-xlarge'],
   required => 1,
   tags => { after_element => \&help,
             help => 'The path to the certificate you submitted to Paypal.' },
  );

has_field key_file =>
  (
   type => 'Path',
   element_class => ['input-xlarge'],
   required => 1,
   tags => { after_element => \&help,
             help => 'The path to the associated key of the certificate you submitted to Paypal.' },
  );

has_field paypal_cert_file =>
  (
   type => 'Path',
   element_class => ['input-xlarge'],
   required => 1,
   tags => { after_element => \&help,
             help => 'The path to the Paypal certificate you downloaded.' },
  );

has_field email_address =>
  (
   type => 'Text',
   required => 1,
   tags => { after_element => \&help,
             help => 'The email address associated to your paypal account.' },
  );

has_field payment_type =>
  (
   type     => 'Select',
   required => 1,
   default  => '_xclick',
   options  => [{value => '_xclick', label => 'Buy Now'}, {value => '_donations', label => 'Donations'}],
   tags => { after_element => \&help,
             help => 'The type of transactions this source will do (donations or sales).' },
  );

has_field 'domains' =>
  (
   type => 'Text',
   label => 'Authorized domains',
   required => 1,
   default => pf::Authentication::Source::PaypalSource->meta->get_attribute('domains')->default,
   element_attr => {'placeholder' => pf::Authentication::Source::PaypalSource->meta->get_attribute('domains')->default},
   element_class => ['input-xlarge'],
   tags => { after_element => \&help,
             help => 'Comma separated list of domains that will be resolve with the correct IP addresses.' },
  );


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
