package pf::ast::functions;

=head1 NAME

pf::ast::functions -

=head1 DESCRIPTION

pf::ast::functions

=cut

use strict;
use warnings;
use DateTime;
use DateTime::Format::Strptime;
use DateTime::Duration;

our %FUNCS = (
    'Date.Diff' => \&Diff,
    'Date.Now' => \&Now,
    'Date.Parse' => \&Parse,
);

sub Diff {
    my ($ctx, $unit, $a, $b) = @_;
    $unit = lc($unit);
    my $method ="delta_$unit";
    return $a->$method($b)->$method();
}

sub Now {
   DateTime->now(); 
}

sub Parse {
    my ($ctx, $f, $string) = @_;
    my $strp = DateTime::Format::Strptime->new(pattern => $f);
    return $strp->parse_datetime($string);
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
