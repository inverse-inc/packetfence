package pfappserver::Form::Config::Syslog::server;

=head1 NAME

pfappserver::Form::Config::Syslog::server -

=cut

=head1 DESCRIPTION

pfappserver::Form::Config::Syslog::server

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Syslog';
with 'pfappserver::Base::Form::Role::Help';

has_field proto => (
    type => 'Select',
    options => [{label => 'udp', value => 'udp'}, {label => 'tcp', value => 'tcp'}],
    required => 1,
);

has_field host => (
    type => 'Text',
    required => 1,
);

has_field port => (
    type => 'PosInteger',
    default => '514',
    required => 1,
);

has_block definition =>
  (
    render_list => [qw(type proto host port logs)],
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

