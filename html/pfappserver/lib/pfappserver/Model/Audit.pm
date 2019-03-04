package pfappserver::Model::Audit;

=head1 NAME

pfappserver::Model::Audit - Provides audit logging in catalyst

=cut

=head1 DESCRIPTION

pfappserver::Model::Audit

=cut

use strict;
use warnings;
use pf::log;
use pf::file_paths qw($admin_audit_log);
use JSON::MaybeXS;
use Moose;

extends qw(Catalyst::Model);

has audit_log_path => ( is => 'ro', default => $admin_audit_log);

has file_handle => ( is => 'ro', builder => '_build_file_handle', lazy => 1);

has json => ( is => 'ro', isa => JSON::MaybeXS::JSON(),  default => sub { JSON::MaybeXS->new });


=head2 _build_file_handle

Build the file handle for the audit

=cut

sub _build_file_handle {
    my ($self) = @_;
    my $audit_log_path = $self->audit_log_path;
    my $fh;
    unless (open($fh, '>>', $audit_log_path)) {
        my $logger = get_logger();
        my $msg = "Cannot open $audit_log_path '$!'";
        $logger->error($msg);
        die $msg;
    }
    return $fh;
}

=head2 write_entry

Write a entry to the the audit log appending a new line if needed

=cut

sub write_entry {
    my ($self, $entry) = @_;
    $entry .= "\n" unless $entry =~ /\n$/;
    return $self->_write_audit_entry($entry);
}

=head2 write_json_entry

Writes a json object to the audit log

=cut

sub write_json_entry {
    my ($self, $args) = @_;
    return $self->_write_audit_entry($self->json->encode($args) ."\n");
}

=head2 _write_audit_entry

Writes to the audit log

=cut

sub _write_audit_entry {
    my ($self, $line) = @_;
    my $fh = $self->file_handle;
    $fh->write($line);
}

=head2 ACCEPT_CONTEXT

Function to allow Catalyst to initialize the Object

=cut

sub ACCEPT_CONTEXT {
    my ($class, $c, %args) = @_;
    return $class->new(\%args);
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

