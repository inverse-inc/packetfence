package pf::cmd::pf::pfconfig;
=head1 NAME

pf::cmd::pf::pfconfig add documentation

=head1 SYNOPSIS

 pfcmd pfonfig <command> <namespace>

  Commands:

   expire <namespace>  | expire a pfconfig namespace 
   reload              | reload all pfconfig namespaces
   list                | list all pfconfig namespaces
   show <namespace>    | rebuild and display a pfconfig namespace
   get <namespace>     | display a pfconfig namespace from pfconfig process
   clear_overlay       | clear all overlayed namespaces of pfconfig

=head1 DESCRIPTION

pf::cmd::pf::pfconfig

=cut

use strict;
use warnings;
use pfconfig::manager;
use pfconfig::util;
use pfconfig::cached;
use Data::Dumper;
use pf::constants::exit_code qw($EXIT_SUCCESS);
use base qw(pf::base::cmd::action_cmd);

=head2 action_expire 

Expire a pfconfig namespace

=cut

sub action_expire {
    my ($self) = @_;
    my ($namespace) = $self->action_args;
    my $manager = pfconfig::manager->new;
    $manager->expire($namespace);
    return $EXIT_SUCCESS;
}

=head2 parse_expire

Verify arguments passed to expire

=cut

sub parse_expire {
    my ($self,@args) = @_;
    return @args == 1;
}

=head2 action_reload

Reload all pfconfig namespaces

=cut

sub action_reload {
    my ($self) = @_;
    my $manager = pfconfig::manager->new;
    $manager->expire_all();
    return $EXIT_SUCCESS;
}

=head2 action_show

Rebuild and display a pfconfig namespace

=cut

sub action_show {
    my ($self) = @_;
    my ($full_namespace) = $self->action_args;
    my ($namespace, @args) = pfconfig::util::parse_namespace($full_namespace);
    my $manager = pfconfig::manager->new;
    if(defined($namespace)){
        my @namespaces = $manager->list_namespaces();
        if ( grep {$_ eq $namespace} @namespaces){
            print Dumper($manager->get_cache($full_namespace));
        }
    }
    return $EXIT_SUCCESS; 
}

=head2 parse_show

Check arguments passed to show

=cut

sub parse_show {
    my ($self,@args) = @_;
    return @args == 1;
}

=head2 action_list

List all pfconfig namespaces

=cut

sub action_list {
    my ($self) = @_;
    my $manager = pfconfig::manager->new;
    my @namespaces = $manager->list_namespaces();
    foreach my $namespace (@namespaces){
        print "$namespace\n";
    }
    return $EXIT_SUCCESS;
}

=head2 action_get

Display a pfconfig namespace from pfconfig process

=cut

sub action_get {
    my ($self) = @_;
    my ($namespace) = $self->action_args;
    if(defined($namespace)){
        my $obj = pfconfig::cached->new;
        my $response = $obj->_get_from_socket($namespace, "element");
        print Dumper($response);
    }
    return $EXIT_SUCCESS;
}

=head2 parse_get

Verify arguments passed to get

=cut

sub parse_get {
    my ($self,@args) = @_;
    return @args == 1;
}

=head2 action_clear_overlay

Clear all overlayed namespaces of pfconfig

=cut

sub action_clear_overlay {
    my ($self) = @_;
    my $manager = pfconfig::manager->new;
    $manager->clear_overlayed_namespaces(); 
    return $EXIT_SUCCESS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
