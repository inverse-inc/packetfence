package pf::validator::Field;

=head1 NAME

pf::validator::Field -

=head1 DESCRIPTION

pf::validator::Field

=cut

use strict;
use warnings;
use Moose;

has name => (
    isa => 'Str',
    is  => 'ro',
    required => 1,
);

has required => (
    isa => 'Bool',
    is  => 'ro',
    default => 0,
);

has messages => (
    isa => 'HashRef',
    is  => 'ro',
    builder => '_build_messages',
);

has text => (
    is  => 'ro',
    isa => 'Str',
);

sub validate {
    my ($self, $ctx, $val) = @_;
    if ($self->required && !defined $val) {
        $ctx->add_error({ field => $self->name, message => $self->get_message('required') });
    }

    $self->validate_field($ctx, $val);
    return;
}

sub get_message {
    my ($self, $name) = @_;
    my $messages = $self->messages;
    if (exists $messages->{$name}) {
        return $messages->{$name};
    }

    return undef;
}

our %DEFAULT_MESSAGES = (
    required => 'is required',
);

sub _build_messages {
    return \%DEFAULT_MESSAGES,
}

sub validate_field {}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
