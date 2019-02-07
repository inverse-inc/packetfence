package pfappserver::Base::Action::SimpleSearch;

=head1 NAME

/usr/local/pf/html/pfappserver/lib/pfappserver/Base/Action add documentation

=head1 DESCRIPTION

SimpleSearch

=cut

use strict;
use warnings;
use Moose::Role;
use namespace::autoclean;

after execute => sub {
    my ( $self, $controller, $c, %args ) = @_;
    %args = map { $_ => $args{$_}  } grep { $controller->valid_param($_) } keys %args;
    $c->stash(%args);
    my $model_name = $self->attributes->{SimpleSearch}[0];
    if ($c->request->method eq 'POST') {
        # Store columns in the session
        my $columns = $c->request->params->{'column'};
        $columns = [$columns] if (ref($columns) ne 'ARRAY');
        my %columns_hash = map { $_ => 1 } @{$columns};
        my %params = ( lc($model_name) . 'columns' => \%columns_hash );
        $c->session(%params);
    }
    $controller->_list_items( $c, $model_name );
};

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

