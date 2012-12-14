package Base::Action::SimpleSearch;

=head1 NAME

/usr/local/pf/html/pfappserver/lib/pfappserver/Base/Action add documentation

=head1 DESCRIPTION

SimpleSearch 

=cut

use strict;
use warnings;
use Moose;
use namespace::autoclean;
 
BEGIN { extends 'Catalyst::Action'; }

after execute => sub {
    my ( $self, $controller, $c, %args ) = @_;
    %args = map { $_ => $args{$_}  } grep { $controller->valid_param($_) } keys %args;
    $c->stash(%args);
    $controller->_list_items( $c, $self->attributes->{SimpleSearch}[0] );
};

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

