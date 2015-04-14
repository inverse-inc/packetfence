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
  pfcmd node add 00:01:02:03:04:05 status="reg" pid="admin"
  pfcmd node edit 00:01:02:03:04:05 status="reg"
  pfcmd node delete 00:01:02:03:04:05

=head1 DESCRIPTION

pf::cmd::pf::node

=cut

use strict;
use warnings;
use Regexp::Common qw(net);

use base qw(pf::base::cmd::action_cmd);
use pf::node;
use pf::util;
use pf::log;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
my $pid_re = qr{(?:
    ( [a-zA-Z0-9\-\_\.\@\/\:\+\!,]+ )                               # unquoted allowed
    |                                                               # OR
    \" ( [&=?\(\)\/,0-9a-zA-Z_\*\.\-\:\;\@\ \+\!\^\[\]\|\#\\]+ ) \" # quoted allowed
)}xo;

our $VIEW_RE = qr/^ (?: (all) | ( $RE{net}{MAC} ) | (?: ( category | pid  ) \s* [=] \s* $pid_re ))
     (?:
       \s+ ( order ) \s+ ( by )
       \s+ ( [a-zA-Z0-9_]+ )
       (?: \s+ ( asc | desc ))?
     )?
     (?:
       \s+ ( limit )
       \s+ ( \d+ )
       \s* [,] \s*
       ( \d+ )
     )?
$/xms;

our $COUNT_RE = qr/^ (?: (all) | ( $RE{net}{MAC} ) | (?: ( category | pid  ) \s* [=] \s* $pid_re )) \s*/xms;

our @FIELDS = qw(
  mac computername pid category status bypass_vlan nbopenviolations voip
  detect_date regdate unregdate last_connection_type last_switch last_port last_vlan last_ssid last_dot1x_username user_agent dhcp_fingerprint last_arp last_dhcp lastskip notes);

=head2 action_view

handles 'pfcmd node view' command

=cut

sub action_view {
    my ($self) = @_;
    my $params = $self->{params};
    my $method = $self->{method};
    my $id = $self->{id};
    my @rows = &$method($id,%$params);
    $self->print_results(\@rows,\@FIELDS);
    return $EXIT_SUCCESS;
}

=head2 parse_view

parse and validate the arguments for 'pfcmd node view' command

=cut

sub parse_view {
    my ($self,@args) = @_;
    my $cli = join(' ',@args);
    my %params;
    unless($cli =~ $VIEW_RE) {
        return 0;
    }
    if($2) {
        $self->{method} = \&node_view;
        $self->{id} = $2;
    } else {
        $self->{method} = \&node_view_all;
        $self->{id} = 'all';
    }
    if($3) {
        $params{'where'}{'type'}  = $3;
        $params{'where'}{'value'} = $4;
    }
    if($8) {
        $params{orderby} = "order by $8";
        if($9) {
            $params{orderby} .= " $9";
        }
    }
    if($10) {
        my $limit = "limit $11,$12";
        $params{limit} = $limit;
    }
    $self->{params} = \%params;
    return 1;
}

=head2 action_add

handles 'pfcmd node add' command

=cut

sub action_add {
    my ($self) = @_;
    my $mac = $self->{mac};
    if (node_exist($mac)) {
        return $EXIT_FAILURE;
    }
    my ($result) = node_add($mac,%{$self->{params}});
    return $result == 1 ? $EXIT_SUCCESS : $EXIT_FAILURE;
}

=head2 parse_add

parse and validate the arguments for 'pfcmd node add' command

=cut

sub parse_add {
    my ($self,$mac,@args) = @_;
    unless (valid_mac($mac)) {
        print STDERR "invalid mac $mac";
        return;
    }
    $self->{mac} = $mac;
    return $self->_parse_attributes(@args);
}

=head2 action_count

handles 'pfcmd node count' command

=cut

sub action_count {
    my ($self) = @_;
    my $params = $self->{params};
    my $method = $self->{method};
    my $id = $self->{id};
    my @rows = &$method($id,%$params);
    $self->print_results(\@rows,[qw(nb)]);
    return $EXIT_SUCCESS;
}

=head2 parse_view

parse and validate the arguments for 'pfcmd node count' command

=cut

sub parse_count {
    my ($self,@args) = @_;
    my $cli = join(' ',@args);
    my %params;
    unless($cli =~ $COUNT_RE) {
        return 0;
    }
    $self->{method} = \&node_count_all;
    if($2) {
        $self->{id} = $2;
    } else {
        $self->{id} = 'all';
    }
    if($3) {
        $params{'where'}{'type'}  = $3;
        $params{'where'}{'value'} = $4;
    }
    $self->{params} = \%params;
    return 1;
}

=head2 action_edit

handles 'pfcmd node edit' command

=cut

sub action_edit {
    my ($self) = @_;
    my $mac = $self->{mac};
    unless (node_exist($mac)) {
        print STDERR "node $mac does not exist\n";
        return $EXIT_FAILURE;
    }
    my ($result) = node_modify($mac,%{$self->{params}});
    return $result == 1 ? $EXIT_SUCCESS : $EXIT_FAILURE;
}

=head2 parse_edit

parse and validate the arguments for 'pfcmd node edit' command

=cut

sub parse_edit {
    my ($self,@args) = @_;
    return $self->parse_add(@args);
}

=head2 action_delete

handles 'pfcmd node delete' command

=cut

sub action_delete {
    my ($self) = @_;
    my ($mac) = $self->action_args;
    unless (node_exist($mac)) {
        return $EXIT_FAILURE;
    }
    my $r = node_delete($mac);
    unless($r) {
        my $error = "Cannot delete node $mac since there are some records in locationlog table "
                    . "indicating that this node might still be connected and active on the network ";
        print STDERR $error,"\n";
        get_logger->error($error);
        return $EXIT_FAILURE;
    }
    return $EXIT_SUCCESS;
}

=head2 parse_delete

parse and validate the arguments for 'pfcmd node delete' command

=cut

sub parse_delete {
    my ($self,@args) = @_;
    return unless @args == 1;
    return valid_mac($args[0]);
}

=head2 _parse_attributes

parse and validate the arguments for 'pfcmd node add|edit' commands

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

=head2 print_results

print the results of a query;

=cut

sub print_results {
    my ($self,$rows,$headings) = @_;
    my $delimiter = '|';
    print join($delimiter,@$headings),"\n";
    foreach my $row (@$rows) {
        $self->cleanup_row($row,$headings);
        print join($delimiter,@{$row}{@$headings}),"\n";
    }
}

=head2 cleanup_row

Clean up the row for display

=cut

sub cleanup_row {
    my ($self,$row,$headings) = @_;
    foreach my $field (@$headings) {
        $row->{$field} //= '';
    }
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

