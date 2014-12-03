package pf::detect::parser::security_onion;

=head1 NAME

pf::detect::parser::security_onion add documentation

=cut

=head1 DESCRIPTION

pf::detect::parser::security_onion

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::detect::parser);

sub parse {
    my ($self,$line) = @_;
    my $data;

    if (index($line, "OSSEC") == -1) {
        # Split the line on the Curly Brace { }
        # Thanks to the guys on Freenode:#perl and google for helping
        # with this regex.
        my @Step1 = split(m/[{}](?![^{}!()]*\))/, $line);

        # The stuff we need in in position 4
        my @Step2 = split(" ", $Step1[4]);

        $data = {
            srcip => $Step2[0],
            sid   => $Step2[6],
            descr => $Step1[3],
        }
    }
    return $data;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

