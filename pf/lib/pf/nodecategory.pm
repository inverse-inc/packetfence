package pf::nodecategory;

=head1 NAME

pf::nodecategory

=cut

use strict;
use warnings;

our (%nodeCategories);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(nodecategory_view_all nodecategory_view);
}

use lib qw(/usr/local/pf/lib);
use pf::config;
use pf::util;
use pf::db;
use Config::IniFiles;

if ( -e $node_categories_file ) {
    tie %nodeCategories, 'Config::IniFiles',
        ( -file => $node_categories_file );
}
if ( defined(%nodeCategories) ) {
    foreach my $section ( tied(%nodeCategories)->Sections ) {
        foreach my $key ( keys %{ $nodeCategories{$section} } ) {
            $nodeCategories{$section}{$key} =~ s/\s+$//;
        }
    }
}

sub nodecategory_view_all {
    my @catArray;
    foreach my $catName ( sort keys %nodeCategories ) {
        push @catArray,
            {
            'name'        => $catName,
            'sql'         => $nodeCategories{$catName}->{'sql'},
            'description' => $nodeCategories{$catName}->{'description'}
            };
    }
    return @catArray;
}

sub nodecategory_view {
    my ($catName) = @_;
    my @catArray;
    if ( exists( $nodeCategories{$catName} ) ) {
        push @catArray,
            {
            'name'        => $catName,
            'sql'         => $nodeCategories{$catName}->{'sql'},
            'description' => $nodeCategories{$catName}->{'description'}
            };
    }
    return @catArray;
}

=head1 COPYRIGHT

Copyright (C) 2008 Inverse <dgehl@inverse.ca>

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
