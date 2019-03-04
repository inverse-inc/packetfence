package pf::factory::report;

=head1 NAME

pf::factory::report

=cut

=head1 DESCRIPTION

The factory for reports

=cut

use strict;
use warnings;

use List::MoreUtils qw(any);
use pf::Report;

use pf::config qw(%ConfigReport);

sub factory_for { 'pf::Report' }

=head2 new

Will create a new pf::report sub class  based off the name of the provider
If no provider is found the return undef

=cut

sub new {
    my ($class,$id) = @_;
    my $report;
    my $data = $ConfigReport{$id};
    if ($data) {
        $data->{id} = $id;
        $report = factory_for->new($data);
    }
    return $report;
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


