package pf::cmd::config_store;
=head1 NAME

pf::cmd::config_store add documentation

=cut

=head1 DESCRIPTION

pf::cmd::config_store

=cut

use strict;
use warnings;
use base qw(pf::cmd::cmd_action);

sub action_clone {
    my ($self) = @_;
    my $configStore = $self->configStore;
    my ($to,$from) = @{$self->{action_args}};
    $configStore->copy($to,$from);
    return $configStore->commit;
}

sub action_view {

}

sub action_delete {
    my ($self) = @_;
    my $configStore = $self->configStore;
    my ($id) = @{$self->{action_args}};
    $configStore->remove($id);
}

sub action_create {

}

sub action_edit {

}

sub configStore { $_[0]->configStoreName->new }

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

