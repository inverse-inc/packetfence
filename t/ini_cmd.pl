#!/usr/bin/perl

=head1 NAME

ini_files -

=head1 DESCRIPTION

ini_files

=cut

use strict;
use warnings;
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::IniFiles;
use File::Copy qw(copy);

our %CMDS = (
    add => \&add,
);
my ($file, $cmd, @args) = @ARGV;

if (!defined $file) {
    die "file not given\n";
}

if (!defined $cmd) {
    die "command not given\n";
}

if (!exists $CMDS{$cmd}) {
    die "$cmd is not valid\n";
}

if (-f $file) {
    copy($file, "${file}.bak") or die "$!";
}

my $ini = pf::IniFiles->new(
    -file => $file,
    -allowempty => 1,
);

$CMDS{$cmd}->($ini, @args);

sub add {
    my ($ini, @args) = @_;
    while (@args) {
        my $section = shift @args;
        my $field = shift @args;
        my $value = shift @args;
        if ($ini->exists($section, $field)) {
            $ini->setval($section, $field, $value);
        } else {
            $ini->newval($section, $field, $value);
        }
    }

    $ini->RewriteConfig();
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
