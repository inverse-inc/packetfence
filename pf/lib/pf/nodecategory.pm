#
# Copyright 2008 Inverse <dgehl@inverse.ca>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

package pf::nodecategory;

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

1;
