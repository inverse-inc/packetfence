package pf::validator::Moose;

=head1 NAME

pf::validator::Moose -

=head1 DESCRIPTION

pf::validator::Moose

=cut

use strict;
use warnings;
use Moose;
use Moose::Exporter;
use Moose::Util::MetaRole;
Moose::Exporter->setup_import_methods(
    with_meta => [ 'has_field'],
    also        => 'Moose',
);

sub init_meta {
    my $class = shift;
 
    my %options = @_;
    Moose->init_meta(%options);
    my $meta = Moose::Util::MetaRole::apply_metaroles(
        for             => $options{for_class},
        class_metaroles => {
            class => [ 'pf::validator::Meta::Role' ]
        }
    );
    return $meta;
}

sub has_field {
	my ($meta, $name, %options) = @_;
    unless ($meta->found_pfv) {
        my @linearized_isa = $meta->linearized_isa;
        if (!grep { $_ eq 'pf::validator' } @linearized_isa) {
            die "Package '" . $linearized_isa[0] . "' uses pf::validator::Moose without extending pf::validator";
        }

        $meta->found_pfv(1);
    }
    my $names = ( ref($name) eq 'ARRAY' ) ? $name : [ ($name) ];
	$meta->add_to_field_list( { name => $_, %options } ) for @$names;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

use namespace::autoclean;

1;
