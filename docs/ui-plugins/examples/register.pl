#!/usr/bin/perl

=head1 NAME

register.pl - an example of a Perl plugin registering itself

=head1 SYNOPSIS

  register.pl register <name> <host> <port>
  register.pl deregister <name>
  register.pl list

=head1 DESCRIPTION

Registers an admin UI plugin with the PacketFence Perl accessors
(pf::ui_plugins): PacketFence reads its database credentials from its own
configuration, the plugin never handles them.

Call "register" once the plugin service serves /manifest.json, "deregister"
when it stops, eg in a systemd unit:

  ExecStartPost=/usr/local/pf/docs/ui-plugins/examples/register.pl register hello 127.0.0.1 8090
  ExecStopPost=/usr/local/pf/docs/ui-plugins/examples/register.pl deregister hello

or in a Kubernetes container lifecycle (postStart, preStop).

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::error qw(is_error);
use pf::ui_plugins;

my ($action, @args) = @ARGV;
$action //= '';

if ($action eq 'register' && @args == 3) {
    my ($name, $host, $port) = @args;
    my ($status, $error) = pf::ui_plugins::register({ name => $name, host => $host, port => $port });
    die "$error\n" if is_error($status);
    print "UI plugin $name registered at http://$host:$port\n";
} elsif ($action eq 'deregister' && @args == 1) {
    my ($status, $error) = pf::ui_plugins::deregister($args[0]);
    die "$error\n" if is_error($status);
    print "UI plugin $args[0] deregistered\n";
} elsif ($action eq 'list' && @args == 0) {
    my $registrations = pf::ui_plugins::list() // die "unable to read the registrations\n";
    for my $name (sort keys %$registrations) {
        my $r = $registrations->{$name};
        print "$name http://$r->{host}:$r->{port}\n";
    }
} else {
    die "usage: $0 register <name> <host> <port> | deregister <name> | list\n";
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
