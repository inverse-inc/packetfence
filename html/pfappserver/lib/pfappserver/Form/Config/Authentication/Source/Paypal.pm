package pfappserver::Form::Config::Authentication::Source::Paypal;

=head1 NAME

pfappserver::Form::Config:::Authentication::Source::Paypal add documentation

=cut

=head1 DESCRIPTION

pfappserver::Form::Config:::Authentication::Source::Paypal

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Authentication::Source::Billing';

has_field host => (
    type => 'Select',
    options => [{label => 'api.paypal.com', value => 'api.paypal.com'}, {label => 'api.sandbox.paypal.com', value => 'api.sandbox.paypal.com',}],
    default => 'api.sandbox.paypal.com',
);

has_field proto => (
    type => 'Select',
    options => [{label => 'http', value => 'https'}, {label => 'https', value => 'https',}],
    default => 'https',
);

has_field port => (
    type => 'Integer',
    default => 443,
);

has_field client_id => (
    type => 'Text',
    required => 1,
);

has_field client_secret => (
    type => 'Text',
    required => 1,
);

has_block definition => (
    render_list => [qw(host proto port client_id client_secret currency)]
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

