package pf::cmd::pf::node;
=head1 NAME

pf::cmd::pf::node add documentation

=head1 SYNOPSIS

 pfcmd node <add|count|view|edit|delete> mac [assignments]

manipulate node entries

examples:
  pfcmd node view all
  pfcmd node view all order by pid limit 10,20
  pfcmd node view pid="admin" order by pid desc limit 10,20
  pfcmd node count all
  pfcmd node add 00:01:02:03:04:05 status="reg",pid="admin"
  pfcmd node delete 00:01:02:03:04:05

=head1 DESCRIPTION

pf::cmd::pf::node

=cut

use strict;
use warnings;
use base qw(pf::base::cmd::action_cmd);
use pf::node;
use pf::util;
use pf::log;


=head2 action_view

taking the action

=cut

sub action_view {
    my ($self) = @_;
    my @args = $self->action_args;
    return ;
}

=head2 action_add

handles command pfcmd node add

=cut

sub action_add {
    my ($self) = @_;
    my $mac = $self->{mac};
    if (node_exist($mac)) {
        return 1;
    }
    my ($result) = node_add($mac,%{$self->{params}});
    return $result == 1 ? 0 : 1;
}

=head2 parse_add

parse and validate the arguments for pfcmd node add

=cut

sub parse_add {
    my ($self,$mac,@args) = @_;
    return unless valid_mac($mac);
    $self->{mac} = $mac;
    return $self->_parse_attributes(@args);
}

=head2 action_count

=cut

sub action_count {
    my ($self) = @_;
    return ;
}

=head2 action_edit

=cut

sub action_edit {
    my ($self) = @_;
    my $mac = $self->{mac};
    unless (node_exist($mac)) {
        return 1;
    }
    my ($result) = node_modify($mac,%{$self->{params}});
    return $result == 1 ? 0 : 1;
}

=head2 parse_edit

parse and validate the arguments for pfcmd node edit (The same as parse_add)

=cut

sub parse_edit {
    my ($self) = @_;
    return $self->parse_add;
}

=head2 action_delete

=cut

sub action_delete {
    my ($self) = @_;
    my ($mac) = $self->action_args;
    unless (node_exist($mac)) {
        return 1;
    }
    my $r = node_delete($mac);
    unless($r) {
        my $error = "Cannot delete node $mac since there are some records in locationlog table "
                    . "indicating that this node might still be connected and active on the network ";
        print STDERR $error,"\n";
        get_logger->error($error);
        return 1;
    }
    return 0;
}

=head2 parse_delete

=cut

sub parse_delete {
    my ($self,@args) = @_;
    return unless @args == 1;
    return valid_mac($args[0]);
}

=head2 _parse_attributes

=cut

sub _parse_attributes {
    my ($self,@attributes) = @_;
    my %params;
    for my $attribute (@attributes) {
        if($attribute =~ /^([a-zA-Z0-9_-]+)=(.*)$/ ) {
            $params{$1} = $2;
        } else {
            print STDERR "$attribute is badily formatted\n";
            return 0;
        }
    }
    $self->{params} = \%params;
    return 1;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

