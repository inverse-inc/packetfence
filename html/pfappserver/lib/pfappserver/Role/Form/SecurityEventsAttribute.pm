package pfappserver::Role::Form::SecurityEventsAttribute;

=head1 NAME

pfappserver::Role::Form::SecurityEventsAttribute -

=cut

=head1 DESCRIPTION

pfappserver::Role::Form::SecurityEventsAttribute

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose::Role;
use pf::ConfigStore::SecurityEvents;

has security_events => ( is => 'rw', builder => '_build_security_events');

sub _build_security_events {
    my ($self) = @_;
    my $cs = pf::ConfigStore::SecurityEvents->new;
    return $cs->readAll('id');;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

