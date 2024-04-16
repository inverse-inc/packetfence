#!/usr/bin/perl

=head1 NAME

flatten -

=head1 DESCRIPTION

Help create a flatten view of a json doc for provisioning_filters

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use JSON::MaybeXS;
use Data::Dumper;
use pf::file_paths qw($provisioning_filters_meta_config_default_file);
use pf::IniFiles;

my $file = $ARGV[0];
my $entry = $ARGV[1];
my $data = do {
    open(my $fh, "<", $file) or die "$!";
    local $/ = undef;
    <$fh>
};

my $json = decode_json($data);
my @fields;
flatten("", $json, \@fields);
@fields = sort @fields;
if (defined $entry) {
    my $ini = pf::IniFiles->new(-file => $provisioning_filters_meta_config_default_file) or die "";
    print Dumper($ini);
    $ini->AddSection($entry);
    $ini->delval($entry, 'fields');
    $ini->newval($entry, 'fields', @fields);
    $ini->RewriteConfig();
} else {
    for my $f (@fields) {
        print "$f\n";
    }
}

sub flatten {
    my ($prefix, $data, $array) = @_;
    while (my ($k, $v) = each %$data) {
        my $t = ref($v);
        if ($t eq 'HASH') {
            flatten("${prefix}${k}.", $v, $array);
        }
        elsif ($t eq '') {
            push @$array, "${prefix}${k}";
        }
    }
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

