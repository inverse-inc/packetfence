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

sub validate_connect_port {
    my ($self) = @_;
    my $value  = $self->value;
    my $port   = $value->{pfconnector_port};
    return if !defined $port || length($port) == 0;
    my $id      = $value->{id};
    my $sources = pf::authentication::getAuthenticationSourcesByType('RADIUS');

    for my $source (@$sources) {
        if ( $id eq $source->{id} ) {
            next;
        }

        my $p = $source->{pfconnector_port};
        if ( defined $p && $p == $port ) {
            $self->field('pfconnector_port')
              ->add_error('Port should be unique');
        }
    }

    tie our %DnsConnectors, 'pfconfig::cached_hash', "config::DnsConnectors";
    for my $data ( values %DnsConnectors ) {
        my $p = $data->{pfconnector_port};
        if ( defined $p && $p == $port ) {
            $self->field('pfconnector_port')
              ->add_error('Port should be unique');
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

