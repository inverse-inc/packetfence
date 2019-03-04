package pf::services::manager::httpd_proxy;

=head1 NAME

pf::services::manager::httpd_proxy add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::httpd_proxy

=cut

use strict;
use warnings;
use Moo;
use pf::config qw(%Config @internal_nets);
use pf::util;

extends 'pf::services::manager::httpd';

has '+name' => (default => sub { 'httpd.proxy' } );

sub isManaged {
    my ($self) = @_;
    return  isenabled($Config{'fencing'}{'interception_proxy'}) && $self->SUPER::isManaged();
}

sub additionalVars {
    my ($self) = @_;
    my %vars = (
        proxy_ports => [split(/ *, */,$Config{'fencing'}{'interception_proxy_port'})],
    );
    return %vars;
}

sub port { 444 }

sub vhosts {
    return [map {
        (defined $_->{Tvip} && $_->{Tvip} ne '') ?  $_->{Tvip} : $_->{Tip}
    } @internal_nets];
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
