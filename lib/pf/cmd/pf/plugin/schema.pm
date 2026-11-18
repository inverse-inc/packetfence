package pf::cmd::pf::plugin::schema;

=head1 NAME

pf::cmd::pf::plugin::schema

=head1 SYNOPSIS

 pfcmd plugin schema <command> <name> [options]

  Commands:
   apply <name> [--defaults-file=<file>]          | create or upgrade the tables of the package to the version of its descriptor
   check <name>                                   | exit 0 when the tables are at the version of the descriptor, 1 otherwise
   drop <name> [--defaults-file=<file>] [--force] | drop the tables of the package (its teardown.sql)

  Options:
   --defaults-file=<file> | mysql client options file of a database user that can create and alter tables
                          | (without it: the MariaDB root user through the local socket, no password)
   --force                | drop the tables on a cluster member: every node shares them

=head1 DESCRIPTION

The package declares its name, version and schema directory in
conf/plugins.d/<name>.conf. See pf::ui_plugins::schema and the Developers
Guide, "Admin UI plugins".

apply and drop exit 2 when they cannot connect to the database as a user that
can create tables: the message gives the command to run by hand.

=cut

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray);
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::ui_plugins::schema;
use base qw(pf::base::cmd::action_cmd);

our $EXIT_NO_CONNECTION = 2;

sub _parse {
    my ($self, $allowed, @args) = @_;
    my %options;
    local $SIG{__WARN__} = sub { $self->{help_msg} = $_[0] };
    return 0 if !GetOptionsFromArray(\@args, \%options, @$allowed);
    if (@args != 1) {
        $self->{help_msg} = "one package name expected\n";
        return 0;
    }
    $self->{name} = $args[0];
    $self->{options} = { map { my $k = $_; $k =~ s/-/_/g; ($k => $options{$_}) } keys %options };
    return 1;
}

sub parse_apply { my ($self, @args) = @_; $self->_parse(['defaults-file=s'], @args) }
sub parse_check { my ($self, @args) = @_; $self->_parse([], @args) }
sub parse_drop  { my ($self, @args) = @_; $self->_parse(['defaults-file=s', 'force'], @args) }

=head2 action_apply

=cut

sub action_apply {
    my ($self) = @_;
    my $name = $self->{name};
    my @applied = eval { pf::ui_plugins::schema::apply($name, %{$self->{options}}) };
    return $self->_failed("apply", $@) if $@;
    if (@applied) {
        print "The tables of $name are now at version $applied[-1] (applied: @applied)\n";
    } else {
        print "The tables of $name are up to date\n";
    }
    return $EXIT_SUCCESS;
}

=head2 action_check

=cut

sub action_check {
    my ($self) = @_;
    my ($ok, $message) = pf::ui_plugins::schema::check($self->{name});
    if ($ok) {
        print $message;
        return $EXIT_SUCCESS;
    }
    print STDERR $message;
    return $EXIT_FAILURE;
}

=head2 action_drop

=cut

sub action_drop {
    my ($self) = @_;
    my $name = $self->{name};
    eval { pf::ui_plugins::schema::drop($name, %{$self->{options}}) };
    return $self->_failed("drop", $@) if $@;
    print "The tables of $name are dropped\n";
    return $EXIT_SUCCESS;
}

sub _failed {
    my ($self, $action, $error) = @_;
    print STDERR $error;
    if ($error =~ /^cannot connect to the database/) {
        print STDERR "Run it with a mysql client options file of a user that can create and alter tables:\n";
        print STDERR "  pfcmd plugin schema $action $self->{name} --defaults-file=<file>\n";
        return $EXIT_NO_CONNECTION;
    }
    return $EXIT_FAILURE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
