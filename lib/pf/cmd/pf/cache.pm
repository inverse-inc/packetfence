package pf::cmd::pf::cache;
=head1 NAME

pf::cmd::pf::cache add documentation

=head1 SYNOPSIS

 pfcmd cache <namespace> <options>
 pfcmd cache all clear

Namespaces:

  accounting
  clustering
  configfiles
  configfilesdata
  fingerbank
  firewall_sso
  httpd.admin
  httpd.portal
  ldap_auth
  person_lookup
  pfdns
  provisioning
  route_int
  switch
  switch.overlay
  local_mac

Options:

  list           | list all keys in the cache
  clear          | clear the cache
  expire         | expire all values in the cache
  remove <key>   | remove the key from the cache
  dump <key>     | dump value the key from the cache

=head1 DESCRIPTION

pf::cmd::pf::cache

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use pf::CHI;
use pf::constants::exit_code qw($EXIT_SUCCESS);
use List::MoreUtils qw(any);

=head1 METHODS

=head2 parseArgs

parsing the arguments for the cache command

=cut

sub parseArgs {
    my ($self) = @_;
    my @args = $self->args;
    if (@args <= 1 || @args > 3 ) {
        print STDERR  "invalid arguments\n";
        return 0;
    }

    my $namespace = shift @args;
    my $action = shift @args;
    if ( ($namespace eq 'all' && $action ne 'clear') && !any { $namespace eq $_ } @pf::CHI::CACHE_NAMESPACES ) {
        print STDERR "the namespace '$namespace' does not exist\n";
        return 0;
    }

    $namespace =~ /^(.*)$/;
    $namespace = $1;

    my $action_method = "action_$action";
    unless ($self->can($action_method)) {
        print STDERR "invalid option '$action'\n";
        return 0;
    }

    if ($action eq 'clear') {
        $self->{caches} = [ map { pf::CHI->new( namespace => $_) } ( $namespace eq 'all'   ? @pf::CHI::CACHE_NAMESPACES  : ($namespace))];
    } else {
        $self->{cache} = pf::CHI->new( namespace => $namespace);
    }

    $self->{action_method} = $action_method;
    $self->{key} = shift @args if $action eq 'remove' || $action eq 'dump' ;
    return 1;
}

=head2 action_list

Handles the list action

=cut

sub action_list {
    my ($self) = @_;
    my $cache = $self->{cache};
    print join("\n",$cache->get_keys),"\n";

}

=head2 action_clear

Handles the clear action

=cut

sub action_clear {
    my ($self) = @_;
    for my $cache (@{$self->{caches}}) {
        print "clearing " . $cache->namespace . "\n";
        for my $key (map { /^(.*)$/;$1  } $cache->get_keys) {
            $cache->remove($key);
        }
    }
}

=head2 action_expire

Handles the remove action

=cut

sub action_remove {
    my ($self) = @_;
    my $cache = $self->{cache};
    $cache->remove($self->{key});
}

=head2 action_dump

Handles the dump action

=cut

sub action_dump {
    my ($self) = @_;
    require Data::Dumper;
    my $cache = $self->{cache};
    print Data::Dumper::Dumper($cache->get($self->{key}));
}


=head2 action_expire

Handles the expire action

=cut

sub action_expire {
    my ($self) = @_;
    my $cache = $self->{cache};
    for my $key ( map { /^(.*)$/;$1 } $cache->get_keys) {
        $cache->remove($key) if $cache->exists_and_is_expired($key);
    }
}

=head2 _run

performs the action of the command

=cut

sub _run {
    my ($self) = @_;
    my $action_method = $self->{action_method};
    $self->$action_method();
    return 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

