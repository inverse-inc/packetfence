package pf::CHI::Request;

=head1 NAME

pf::CHI::Request -

=cut

=head1 DESCRIPTION

pf::CHI::Request

=cut

use strict;
use warnings;
use CHI::Memoize qw(memoize memoized);
use base qw(CHI);
our %CACHE;

use Exporter qw(import);

our @EXPORT_OK = qw(
    pf_memoize
);


__PACKAGE__->config({
    storage => {
        memory => {
            driver     => 'Memory',
            datastore  => \%CACHE,
            serializer => 'Sereal',
        },
        raw_memory => {
            driver     => 'RawMemory',
            datastore  => \%CACHE,
        },
    },
    namespace => {
       'pf::node::_node_exist' => {
           storage => 'raw_memory',
       },
    },
    memoize_cache_objects => 1,
    defaults              => {'storage' => 'memory'},
});

sub clear_all {
    %CACHE = ();
}

sub pf_memoize {
    my ($func) = @_;
    memoize($func, cache => pf::CHI::Request->new(namespace => $func));
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

