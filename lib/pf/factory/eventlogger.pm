package pf::factory::eventlogger;

=head1 NAME

pf::factory::event_logger -

=head1 DESCRIPTION

pf::factory::event_logger

=cut

use strict;
use warnings;
use Module::Pluggable
  search_path => 'pf::eventlogger',
  sub_name    => 'modules',
  require     => 1,
  inner       => 0,
;

our @MODULES = __PACKAGE__->modules;

our %TYPES = map { my $p = $_;my $t = $_; $t =~ s/pf::eventlogger:://; $t => $p } @MODULES;

sub new {
    my ($class, $id, $data) = @_;
    my $type = $data->{type};
    die "type is undefined" if !defined $type;
    die "type '$type' is invalid" if !exists $TYPES{$type};
    return $TYPES{$type}->new($data);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
