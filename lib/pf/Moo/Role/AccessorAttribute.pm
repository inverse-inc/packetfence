package pf::Moo::Role::AccessorAttribute;
=head1 NAME

pf::Moo::Role::AccessorAttribute add documentation

=cut

=head1 DESCRIPTION

pf::Moo::Role::AccessorAttribute

=cut

use strictures 1;

use Moo::Role;

require pf::MooX::AccessorAttribute;

around generate_method => sub {
    my $orig = shift;
    my $self = shift;
    # would like a better way to disable XS

    my ($into, $name, $spec) = @_;
    my $accessor_attribute = $spec->{accessor_attribute};
    if( ref($accessor_attribute) eq 'HASH' ) {
        my $value = $accessor_attribute->{value};
        my $new_name = $accessor_attribute->{name};
        $self->$orig($into,$new_name,{is=>'rw', default => sub { return $value; }});
    }
    return $self->$orig(@_);
};

around register_attribute_specs => sub {
    my $orig = shift;
    my $self = shift;
    my ($name, $spec) = @_;
    my $accessor_attribute = $spec->{accessor_attribute};
    if( ref($accessor_attribute) eq 'HASH' ) {
        my $value = $accessor_attribute->{value};
        my $new_name = $accessor_attribute->{name};
        $self->$orig($new_name,{is=>'rw', default => sub { return $value; }});
    }
    return $self->$orig(@_);
};

1;

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

