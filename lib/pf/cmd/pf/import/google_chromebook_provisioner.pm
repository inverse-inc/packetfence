package pf::cmd::pf::import::google_chromebook_provisioner;

=head1 NAME

pf::cmd::pf::import::google_chromebook_provisioner -

=head1 SYNOPSIS

pfcmd import google_chromebook_provisioner provisioner_id

=head1 DESCRIPTION

pf::cmd::pf::import::google_chromebook_provisioner

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use Role::Tiny::With;
use pf::constants qw($TRUE $FALSE);
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::factory::provisioner;

=head2 parseArgs

Parse the arguments for this command

=cut

sub parseArgs {
    my ($self) = @_;
    my ($id) = $self->args;
    if (!defined $id || length($id) == 0) {
        print STDERR "You must specify a provisioner\n";
        return $FALSE;
    }

    my $p = pf::factory::provisioner->new($id);
    if (!defined $p) {
        print STDERR "No provisioner ($id) defined\n";
        return $FALSE;
    }

    if (!$p->isa("pf::provisioner::google_workspace_chromebook")) {
        print STDERR " provisioner ($id) is not a pf::provisioner::google_workspace_chromebook\n";
        return $FALSE;
    }

    $self->{provisioner} = $p;
    return $TRUE;
}

=head2 _run

=cut

sub _run {
    my ($self) = @_;
    $self->{provisioner}->importDevices();
    print "Import process complete.\n";
    return $EXIT_SUCCESS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
