package pf::base::cmd::config_store;
=head1 NAME

pf::base::cmd::config_store base class for config store commands

=cut

=head1 DESCRIPTION

pf::base::cmd::config_store

=cut

use strict;
use warnings;
use base qw(pf::base::cmd::action_cmd);
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);

sub action_clone {
    my ($self) = @_;
    my $configStore = $self->configStore;
    my ($from,$to,%attributes) = $self->action_args;
    if ( $configStore->copy($from,$to) ) {
        $configStore->update($to,\%attributes);
        return $configStore->commit ? $EXIT_SUCCESS : $EXIT_FAILURE;
    }
    print "unable able to clone $from to $to\n";
    return $EXIT_FAILURE;
}

sub idKey { 'id' }

sub action_get {
    my ($self)      = @_;
    my ($id)        = $self->action_args;
    my $configStore = $self->configStore;
    my $items;
    my $idKey = $self->idKey;
    if ($id eq 'all') {
        $items = $configStore->readAll($idKey);
    }
    else {
        if ($configStore->hasId($id)) {
            my $item = $configStore->read($id, $idKey);
            $items = [$item] if $item;
        }
    }
    if ($items) {
        my @display_fields = $self->display_fields;
        print join('|', @display_fields), "\n";
        foreach my $item (@$items) {
            print join('|', map {$self->format_param($_)} @$item{@display_fields}), "\n";
        }
    }
    return $EXIT_SUCCESS;
}

sub format_param {
    my ($self,$param) = @_;
    return '' unless defined $param;
    return join(',',@$param) if ref($param) eq 'ARRAY';
    return $param;
}

sub display_fields { }

sub action_delete {
    my ($self) = @_;
    my ($id) = $self->action_args;
    my $configStore = $self->configStore;
    if($configStore->hasId($id) ) {
        $configStore->remove($id);
        my $results =  $configStore->commit;
        return $EXIT_SUCCESS if $results;
    } else {
        print "Unknown item $id!\n";
    }
    return $EXIT_FAILURE;
}

sub parse_clone {
    my ($self,$from,$to,@attributes) = @_;
    return defined $from && defined $to;
    $self->{action_args} = [$from,$to];
    return $self->_parse_attributes(@attributes);
}

sub _id_defined {
    my ($self,$id) = @_;
    return defined $id;
}

*parse_get = \&_id_defined;
*parse_delete = \&_id_defined;

sub action_add {
    my ($self) = @_;
    my $configStore = $self->configStore;
    my ($id,%attributes) = $self->action_args;
    if ($configStore->hasId($id)) {
        print "'$id' already exists!\n";
        return $EXIT_FAILURE;
    }
    $configStore->create($id,\%attributes);
    return $configStore->commit ? $EXIT_SUCCESS : $EXIT_FAILURE;
}

sub action_edit {
    my ($self) = @_;
    my $configStore = $self->configStore;
    my ($id, %attributes) = $self->action_args;
    return $EXIT_FAILURE unless $configStore->hasId($id);
    $configStore->update($id, \%attributes);
    return $configStore->commit ? $EXIT_SUCCESS : $EXIT_FAILURE;
}

sub parse_add {
    my ($self,$id,@attributes) = @_;
    return undef unless defined $id;
    $self->{action_args} = [$id];
    return $self->_parse_attributes(@attributes);
}

sub parse_edit {
    my ($self,$id,@attributes) = @_;
    return undef unless defined $id;
    $self->{action_args} = [$id];
    return $self->_parse_attributes(@attributes);
}

sub _parse_attributes {
    my ($self, @attributes) = @_;
    my $rx = qr/
        ([a-zA-Z_][a-zA-Z0-9_]*)  #The parameter name
        =
        (.*)$
    /x;
    my @action_args;
    foreach my $attribute (@attributes) {
        unless ($attribute =~ /$rx/) {
            print STDERR "$attribute is invalid\n";
            return 0;
        }
        my ($field, $value) = ($1, $2);
        unless ($self->is_valid_field($field, $value) ) {
            print STDERR "$field = $value is an invalid field\n";
            return 0;
        }
        push @action_args, $field, $value;
    }
    push @{$self->{action_args}}, @action_args;
    return 1;
}

sub configStore { $_[0]->configStoreName->new }

sub configStoreName { die "Did not override configStoreName" }


=head2 is_valid_field

Check if field is valid

=cut

sub is_valid_field { 1 }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

