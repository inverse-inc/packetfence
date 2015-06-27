package pfappserver::Form::Config::Authentication::Source::Stripe;

=head1 NAME

pfappserver::Form::Authentication::Source::Stripe add documentation

=cut

=head1 DESCRIPTION

pfappserver::Form::Authentication::Source::Stripe

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Authentication::Source::Billing';

# Form fields
has_field 'test_secret_key' => (
    type => 'Text'
);

has_field 'test_publishable_key' => (
    type => 'Text'
);

has_field 'live_secret_key' => (
    type => 'Text',
    required => 1
);

has_field 'live_publishable_key' => (
    type => 'Text',
    required => 1
);

has_field 'style' => (
    type    => 'Select',
    default => 'charge',
    options => [{label => 'Charge', value => 'charge'}, {label => 'Subscription', value => 'subscription'}]
);

has_block definition => (
    render_list => [qw(test_secret_key test_publishable_key live_secret_key live_publishable_key style test_mode)]
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

