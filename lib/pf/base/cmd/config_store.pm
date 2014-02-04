package pf::base::cmd::config_store;
=head1 NAME

pf::cmd::config_store add documentation

=cut

=head1 DESCRIPTION

pf::cmd::config_store

=cut

use strict;
use warnings;
use base qw(pf::base::cmd::action_cmd);

sub action_clone {
    my ($self) = @_;
    my $configStore = $self->configStore;
    my ($from,$to,%attributes) = $self->action_args;
    if ( $configStore->copy($from,$to) ) {
        $configStore->update($to,\%attributes);
        return $configStore->commit ? 0 : 1;
    }
    print "unable able to clone $from to $to\n";
    return 1;
}

sub idKey { 'id' }

sub action_get {
    my ($self) = @_;
    my ($id) = $self->action_args;
    my $configStore = $self->configStore;
    my $items;
    my $idKey = $self->idKey;
    if($id eq 'all') {
        $items = $configStore->readAll( $idKey );
    } else {
        if($configStore->hasId($id) ) {
            $items = [$configStore->read($id, $idKey )];
        }
    }
    if ($items) {
        my @display_fields = $self->display_fields;
        print join('|',@display_fields),"\n";
        foreach my $item (@$items) {
            print join('|',map { $self->format_param($_) } @$item{@display_fields}),"\n";
        }
    }
    return 0;
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
        return 0 if $results;
    } else {
        print "Unknown item $id!\n";
    }
    return 1;
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
        return 1;
    }
    $configStore->create($id,\%attributes);
    return $configStore->commit ? 0 : 1;
}

sub action_edit {
    my ($self) = @_;
    my $configStore = $self->configStore;
    my ($id,%attributes) = $self->action_args;
    return 1 unless $configStore->hasId($id);
    $configStore->update($id,\%attributes);
    return $configStore->commit ? 0 : 1;
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
    my ($self,@attributes) = @_;
    my $rx = qr/
        ([a-zA-Z_][a-zA-Z0-9_]*)  #The parameter name
        =
        (?|
            "([&=?()\/,0-9a-zA-Z_\*\.\-\:_\;\@\ \+\!]*)" |
            ([\/0-9a-zA-Z_\*\.\-\:_\;\@]+)
        )
    /x;
    my @action_args;
    foreach my $attribute (@attributes) {
        my (@matches) = ($attribute =~ /$rx/g);
        push @action_args, @matches;
    }
    push @{$self->{action_args}}, @action_args;
    return 1;
}

sub configStore { $_[0]->configStoreName->new }

sub configStoreName { die "Did not override configStoreName" }

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

