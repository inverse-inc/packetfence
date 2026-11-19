package pf::cmd;

=head1 NAME

pf::cmd add documentation

=head1 DESCRIPTION

pf::cmd

=cut

use strict;
use warnings;
use Role::Tiny::With;
with 'pf::cmd::roles::show_help';

=head2 $CALLER_UID

The real uid of the process that ran pfcmd, set by bin/pfcmd.pl before it
switches to root (bin/pfcmd is setuid root). Undefined when the commands are
not run through bin/pfcmd: the real uid of the process is then the caller's.

=cut

our $CALLER_UID;

=head2 caller_uid

The real uid of the caller of pfcmd (see $CALLER_UID).

=cut

sub caller_uid {
    return $CALLER_UID // $<;
}

sub new {
    my ($class,$args) = @_;
    my $self = bless $args,$class;
    return $self;
}

sub run {
    my ($self) = @_;
    if ($self->parseArgs) {
        $self->_run;
    } else {
        $self->showHelp;
    }
}

sub parseArgs {
    my ($self) = @_;
    return $self->args == 0;
}

sub args {
    return @{$_[0]->{args} || []};
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

