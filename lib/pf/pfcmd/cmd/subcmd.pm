package pf::pfcmd::cmd::subcmd;
=head1 NAME

pf::pfcmd::cmd::subcmd add documentation

=cut

=head1 DESCRIPTION

pf::pfcmd::cmd::subcmd

=cut

use strict;
use warnings;
use base qw(pf::pfcmd::cmd);


sub run {
    my ($self) = @_;
    my ($cmd,@args);
    if(@{$self->{args}}) {
        @args = @{$self->{args}};
        my $action = shift @args;
        $cmd = $self->get_cmd($action);
    } else {
        $cmd = $self->default_cmd;
    }
    return $cmd->new(@args)->run;
}

sub get_cmd {
    my ($self,$action) = @_;
    my $base = ref($self) || $self;
    return "${base}::${action}" if defined $action;
    return $self->unknown_cmd;
}


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

