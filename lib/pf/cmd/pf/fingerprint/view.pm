package pf::cmd::pf::fingerprint::view;
=head1 NAME

pf::cmd::pf::fingerprint::view add documentation

=cut

=head1 DESCRIPTION

pf::cmd::pf::fingerprint::view

=cut

use strict;
use warnings;
use base qw(pf::cmd::display);
use pf::os qw(dhcp_fingerprint_view dhcp_fingerprint_view_all);
use pf::config::ui;


sub checkArgs {
    my ($self) = @_;
    my ($id) = @{$self->{args}};
    my $function;
    my %params;
    if(defined $id && $id ne 'all') {
        $function = \&dhcp_fingerprint_view;
    } else {
        $function = \&dhcp_fingerprint_view_all;
    }
    $self->{function} = $function;
    $self->{key} = $id;
    $self->{params} = \%params;
    return 1;
}

sub field_ui { "fingerprint view" }

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

