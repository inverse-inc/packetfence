package pf::triggerParser::provisioner;
=head1 NAME

pf::triggerParser::provisioner - Trigger for provisioner

=cut

=head1 DESCRIPTION

pf::triggerParser::provisioner

=cut

use strict;
use warnings;
use pf::constants::trigger qw($TRIGGER_ID_PROVISIONER);
use Moo;
extends 'pf::triggerParser';

our @TRIGGER_IDS = ($TRIGGER_ID_PROVISIONER);

sub validateTid {
    my ($self, $tid) = @_;
    die("Invalid provisioner trigger id: $tid") if $tid ne $TRIGGER_ID_PROVISIONER;
    return 1;
}

sub search {
    my ($self,$query) = @_;
    my @items = map { { display => $_, value => $_ } } grep { $_ =~ /\Q$query\E/i } @TRIGGER_IDS;
    return \@items;
}

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

1;
