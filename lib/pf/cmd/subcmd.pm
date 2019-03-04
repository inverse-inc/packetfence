package pf::cmd::subcmd;
=head1 NAME

pf::cmd::subcmd for loading command actions on demand

=cut

=head1 DESCRIPTION

pf::cmd::subcmd

This is a base class for ondemand loading of command line actions

=cut

use strict;
use warnings;
use pf::cmd;
use base qw(pf::cmd);
use Module::Load;
use Module::Loaded;
use pf::cmd::help;

=head2 _run
The overridded method to handle the action
=cut

sub _run {
    my ($self) = @_;
    return $self->{subcmd}->new( {parentCmd => $self, args => $self->{subcmd_args}})->run;
}

sub parseArgs {
    my ($self) = @_;
    my ($action,@args) = $self->args;
    my $cmd;
    if (defined $action) {
        my $module;
        if($action eq 'help') {
            $module = $self->helpActionCmd;
        } else {
            my $base = ref($self) || $self;
            $module = "${base}::${action}";
        }
        $module =~ /^(.*)$/;
        $module = $1;
        eval {
            load $module unless is_loaded($module);
            $cmd = $module;
        };
        if($@) {
            my $path = $module . ".pm";
            $path =~ s#::#/#g;
            if ($@ =~ /Can't locate \Q$path\E/m) {
                $self->{help_msg} = "unknown command $action\n";
            } else {
                $self->{help_msg} = "module $module cannot be loaded\n$@\n";
            }
            $cmd = $self->unknownActionCmd;
        } else {
            $self->{subcmd_args} = \@args;
        }
    } else {
        $cmd = $self->noActionCmd;
    }
    $self->{subcmd} = $cmd;
    return 1;
}

=head2 helpActionCmd
    The module that will handle the help action
=cut

sub helpActionCmd { "pf::cmd::help" }

=head2 noActionCmd
    The module that will handle when there is no action defaults to $self->helpActionCmd
=cut

sub noActionCmd {
    my ($self) = @_;
    return $self->helpActionCmd;
}

=head2 unknownActionCmd
    The module that will handle when you cannot load an action defaults to $self->helpActionCmd
=cut

sub unknownActionCmd {
    my ($self) = @_;
    return $self->helpActionCmd;
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

