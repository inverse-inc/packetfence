package pfappserver::Form::Config::Authentication::Source::AdminProxy;

=head1 NAME

pfappserver::Form::Config::Authentication::Source::AdminProxy - Form for the AdminProxySource

=cut

=head1 DESCRIPTION

pfappserver::Form::Config::Authentication::Source::AdminProxy

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Authentication::Source';

has_block definition => (
    render_list => [qw(proxy_addresses user_header group_header)],
);

has_field 'proxy_addresses' => (
    type => 'Text',
    required => 1
);

has_field 'user_header' => (
    type => 'Text',
    required => 1
);

has_field 'group_header' => (
    type => 'Text',
    required => 1
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;
