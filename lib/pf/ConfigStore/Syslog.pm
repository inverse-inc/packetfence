package pf::ConfigStore::Syslog;

=head1 NAME

pf::ConfigStore::Syslog

=cut

=head1 DESCRIPTION

pf::ConfigStore::Syslog

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moo;
use namespace::autoclean;
use pf::constants::syslog;
use pf::util qw(isenabled);
use pf::file_paths qw($syslog_config_file $syslog_default_config_file);
extends 'pf::ConfigStore';

sub configFile { $syslog_config_file }

sub importConfigFile { $syslog_default_config_file }

sub pfconfigNamespace { 'config::Syslog' }

=head2 cleanupAfterRead

Clean up switch data

=cut

sub cleanupAfterRead {
    my ($self, $id, $data) = @_;
    my $logs = $data->{logs};
    if (defined $logs && $logs eq 'ALL') {
        $data->{logs} = $pf::constants::syslog::ALL_LOGS;
        $data->{all_logs} = 'enabled';
    }
    $self->expand_list($data, $self->_fields_expanded);
}

=head2 cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $data) = @_;
    my $all_logs = delete $data->{all_logs};
    if (isenabled ($all_logs)) {
        $data->{logs} = 'ALL';
    }
    $self->flatten_list($data, $self->_fields_expanded);
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(logs);
}

__PACKAGE__->meta->make_immutable;

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
