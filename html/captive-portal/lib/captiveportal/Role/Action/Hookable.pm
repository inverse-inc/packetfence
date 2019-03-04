package captiveportal::Role::Action::Hookable;

=head1 NAME

captiveportal::Role::Action::Hookable add documentation

=cut

=head1 DESCRIPTION

captiveportal::Role::Action::Hookable

=cut

use strict;
use warnings;
use HTTP::Status qw(:constants);
use Moose::Role;
use namespace::autoclean;

=head1 METHODS

=head2 before execute

See if action has a config hook one of the configured

before
after
override

=cut

sub wasSeen {
    my ( $self, $c ) = @_;
    my $seenKey = $self->seenKey;
    my $seenHash = $c->stash->{$seenKey} || {};
    $c->stash( $seenKey => $seenHash );
    my $seen = $seenHash->{ $self->private_path }++;
    return $seen;
}

sub resetSeenCount {
    my ( $self, $c ) = @_;
    my $seenKey = $self->seenKey;
    my $seenHash = $c->stash->{$seenKey} || {};
    $seenHash->{ $self->private_path } = 0;
    $c->stash( $seenKey => $seenHash );
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

