package pf::util::dns;

use strict;
use warnings;

use pf::constants;
use pfconfig::cached_hash;

tie our %passthroughs, 'pfconfig::cached_hash', 'resource::passthroughs';

sub matches_passthrough {
    my ($domain) = @_;

    # undef domains are not passthroughs
    return $FALSE unless(defined($domain));

    # Check for non-wildcard passthroughs
    if(exists($passthroughs{normal}{$domain})) {
        return $TRUE;
    }

    # Check if it matches exactly a wildcard domain
    if(exists($passthroughs{wildcard}{$domain})) {
        return $TRUE;
    }

    # check if its a sub-domain of a wildcard domain
    my @parts = split(/\./, $domain);
    my $last_element = scalar(@parts)-1;
    for (my $i=$last_element; $i>0; $i--) {
        my @sub_parts = @parts[$i..$last_element];
        my $domain = join('.', @sub_parts);
        if(exists($passthroughs{wildcard}{$domain})) {
            return $TRUE;
        }
    }

    # Fallback to not a passthrough
    return $FALSE;
}

1;
