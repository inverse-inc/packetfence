#!/usr/bin/perl
=head1 NAME

switch-template add documentation

=cut

=head1 DESCRIPTION

switch-template

=cut

use strict;
use warnings;
use Text::CSV_XS;
use Getopt::Long;
use Template;
our %Options = ( delimiter => "\t");
my $result = GetOptions (\%Options,"inputfile|i=s", "template|t=s", "delimiter|d=s", "define=s%" );
die "--inputfile and/or --template does not exists" unless exists $Options{inputfile} && exists $Options{template} && -e $Options{inputfile} && -e $Options{template};
my $csv = Text::CSV_XS->new({ sep_char => $Options{delimiter} });
open(my $io,$Options{inputfile}) or die "cannot open $Options{inputfile}";
my $cols = $csv->getline($io);
$csv->column_names($cols);
our %vars = ( %{ $Options{define} },  entries => $csv->getline_hr_all($io) );
our $template = Template->new;
$template->process($Options{template}, \%vars ) || die $template->error;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

