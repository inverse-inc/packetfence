package pf::UnifiedApi::Controller::RestRoute;

=head1 NAME

pf::UnifiedApi::Controller::RestRoute -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::RestRoute

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller';
use pf::ConfigStore;

sub list {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub resource {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub get {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub create {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub remove {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub update {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub replace {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

sub search {
    my ($self) = @_;
    return $self->render_error(404, "Unimplemented");
}

my %WRITE_METHODS = (POST => 1, PUT => 1, PATCH => 1, DELETE => 1);

# Actions sent with a write method that only read the config
my %READ_ONLY_ACTIONS = (search => 1);

=head2 lock_config_store

Lock the config file of the store for the lifetime of the store during a write request,
so concurrent writers do not overwrite each other's changes.
Dies with a pf::ConfigStore::LockTimeout (rendered as a 503) when another writer
keeps the file locked.
Read-only actions sent with a write method (search is a POST) don't lock.

The lock is a flock on the server (or container) handling the request: it
serializes the API writes made on that server.

=cut

sub lock_config_store {
    my ($self, $cs) = @_;
    return unless $WRITE_METHODS{$self->req->method};
    return if $READ_ONLY_ACTIONS{$self->stash->{action} // ''};
    my $locked = $cs->lock_config;
    if (defined $locked && !$locked) {
        die pf::ConfigStore::LockTimeout->new(file => $cs->configFile);
    }
    return $locked;
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

