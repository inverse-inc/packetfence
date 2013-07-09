package pf::cmd::pf::switchlocation::view;
=head1 NAME

pf::cmd::pf::switchlocation::view add documentation

=cut

=head1 DESCRIPTION

pf::cmd::pf::switchlocation::view

=cut

use strict;
use warnings;
use base qw(pf::cmd::display);
use pf::switchlocation;


sub checkArgs {
    my ($self) = @_;
    my ($id,$ifIndex) = @{$self->{args}};
    if (defined $id) {
        my %params = (ifIndex => $ifIndex);
        $self->{function} = \&switchlocation_view_switchport;
        $self->{key} = $id;
        $self->{params} = \%params;
        return 1;
    }
    return 0;
}

sub field_ui { "switchlocation view" }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

