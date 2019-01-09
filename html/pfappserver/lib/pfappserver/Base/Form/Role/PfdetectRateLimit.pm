package pfappserver::Base::Form::Role::PfdetectRateLimit;

=head1 NAME

pfappserver::Base::Form::Role::PfdetectRateLimit -

=head1 DESCRIPTION

pfappserver::Base::Form::Role::PfdetectRateLimit

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose::Role;
with qw(pfappserver::Base::Form::Role::Help);

has_field 'rate_limit' => (
    type    => 'Duration',
    label   => 'Rate Limit',
    default => '0s',
    tags    => {
        after_element => \&help,
        help => 'Rate limit requests.'
    },
);


has_block definition =>
  (
   render_list => [ qw(id type status path rate_limit) ],
  );

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
