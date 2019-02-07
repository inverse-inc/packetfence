package pf::cmd::help;
=head1 NAME

pf::cmd::help

=cut

=head1 DESCRIPTION

pf::cmd::help

A pf::cmd class that extracts the usage from the parentCmd

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use Pod::Find qw(pod_where);

sub run {
    my ($self) = @_;
    my ($cmd) = $self->args;
    my $parentCmd = $self->{parentCmd};
    if(!defined $cmd || $cmd eq 'help') {
        return $parentCmd->showHelp;
    }
    my $base = ref($parentCmd) || $parentCmd;
    my $package = "${base}::${cmd}";
    my $location = pod_where( { -inc => 1 }, $package);
    if ($location) {
        return $self->showHelp($package);
    }
    $parentCmd->{help_msg} = "unknown command \"$cmd\"";
    return $parentCmd->showHelp;
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

