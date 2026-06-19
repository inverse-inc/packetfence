package pf::ConfigStore::Kafka;

=head1 NAME

pf::ConfigStore::Kafka add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::Kafka

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moo;
use namespace::autoclean;
use pf::file_paths qw($kafka_config_file);
extends 'pf::ConfigStore';


sub configFile { $kafka_config_file }

sub pfconfigNamespace {'config::Kafka'}

=head2 cleanupAfterRead

The peer CA PEM spans several lines in kafka.conf, so it is read back as an
array reference (one element per line). Flatten it to a single newline-joined
string so the API returns a string (matching the form schema) and consumers
such as the truststore builder receive usable PEM text.

=cut

sub cleanupAfterRead {
    my ($self, $id, $data) = @_;
    if ($id eq 'ssl') {
        $self->flatten_list_cr($data, 'peer_ca');
    }
    return;
}

=head2 cleanupBeforeCommit

Symmetric counterpart to L</cleanupAfterRead>: should the peer CA arrive as an
array reference (e.g. from a stale client), join it back into a single string
before it is written so it is never persisted as a multi-valued entry.

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $assignments) = @_;
    if ($id eq 'ssl' && ref($assignments->{peer_ca}) eq 'ARRAY') {
        $assignments->{peer_ca} = $self->join_list_cr(@{$assignments->{peer_ca}});
    }
    return;
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

