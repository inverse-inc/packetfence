package pf::pfmon::task::provisioning_compliance_poll;

=head1 NAME

pf::pfmon::task::provisioning_compliance_poll - class for pfmon task provisioning compliance poll

=cut

=head1 DESCRIPTION

pf::pfmon::task::provisioning_compliance_poll

=cut

use strict;
use warnings;
use Moose;
extends qw(pf::pfmon::task);

=head2 run

Polls each provisioner to enforce compliance

=cut

sub run {
    my ($self) = @_;
    foreach my $id (@{pf::ConfigStore::Provisioning->new->readAllIds}) {
        my $provisioner = pf::factory::provisioner->new($id);
        if($provisioner->supportsPolling){
            $provisioner->pollAndEnforce($self->interval);
        }
    }
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
