package pfappserver::Role::Form::ConnectPortValidate;

=head1 NAME

pfappserver::Role::Form::ConnectPortValidate -

=head1 DESCRIPTION

pfappserver::Role::Form::ConnectPortValidate

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose::Role;
use pf::authentication;
use pfconfig::cached_hash;

=head2 validate_connect_port

Ensure the pfconnector_port is not used by another RADIUS source or DNS server.

$kind is the kind of item the form saves ('radius' or 'dns'): only that item is
skipped, a RADIUS source and a DNS server can share an id.

=cut

sub validate_connect_port {
    my ($self, $kind) = @_;
    my $value  = $self->value;
    my $port   = $value->{pfconnector_port};
    return if !defined $port || length($port) == 0;
    my $id      = $value->{id} // '';
    my $sources = pf::authentication::getAuthenticationSourcesByType('RADIUS');

    for my $source (@$sources) {
        next if $kind eq 'radius' && $id eq $source->{id};
        my $p = $source->{pfconnector_port};
        if ( defined $p && length($p) && $p == $port ) {
            return $self->field('pfconnector_port')
              ->add_error("Port $port is already used by the RADIUS source $source->{id}");
        }
    }

    tie our %DnsConnectors, 'pfconfig::cached_hash', "config::DnsConnectors";
    for my $dns_id ( keys %DnsConnectors ) {
        next if $kind eq 'dns' && $id eq $dns_id;
        my $p = $DnsConnectors{$dns_id}{pfconnector_port};
        if ( defined $p && length($p) && $p == $port ) {
            my $dns = $DnsConnectors{$dns_id};
            return $self->field('pfconnector_port')
              ->add_error("Port $port is already used by the DNS server $dns->{ip} of the connector $dns->{connector}");
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

