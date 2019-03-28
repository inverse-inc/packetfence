package pfappserver::Form::Field::Trigger;

=head1 NAME

pfappserver::Form::Field::Trigger -

=head1 DESCRIPTION

pfappserver::Form::Field::Trigger

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );

use pf::constants::trigger qw(
        $TRIGGER_TYPE_ACCOUNTING $TRIGGER_TYPE_DETECT $TRIGGER_TYPE_INTERNAL $TRIGGER_TYPE_MAC $TRIGGER_TYPE_NESSUS $TRIGGER_TYPE_OPENVAS $TRIGGER_TYPE_OS $TRIGGER_TYPE_USERAGENT $TRIGGER_TYPE_VENDORMAC $TRIGGER_TYPE_PROVISIONER $TRIGGER_TYPE_SWITCH $TRIGGER_TYPE_SWITCH_GROUP 
        $SURICATA_CATEGORIES
        $TRIGGER_MAP
);

for my $trigger ($TRIGGER_TYPE_ACCOUNTING, $TRIGGER_TYPE_DETECT, $TRIGGER_TYPE_MAC, $TRIGGER_TYPE_NESSUS, $TRIGGER_TYPE_OPENVAS, $TRIGGER_TYPE_OS, $TRIGGER_TYPE_USERAGENT, $TRIGGER_TYPE_VENDORMAC) {
    has_field $trigger => (
        type => 'Text'
    );
}

while (my ($trigger, $value) = each %$TRIGGER_MAP) {
    has_field $trigger => (
        type => 'Select',
        options_method => sub {
            return map { { label => $_, value => $_ } } keys %$value;
        },
    );
}

=head2 inflate

inflate the value from the config store

=cut

sub inflate {
    my ($self, $value) = @_;
    if (ref($value) eq 'HASH') {
        return $value;
    }

    my %trigger;
    if ($value =~ /\((.*)\)/) {
        $value = $1;
    }

    for my $t (split(/\&/, $value)) {
        my ($k, $v) = split (/::/, $t, 2);
        $trigger{lc($k)} = $v;
    }

    return \%trigger;
}


=head2 deflate

deflate

=cut

sub deflate {
    my ($self, $value) = @_;
    my @vals;
    while (my ($k, $v) = each %$value) {
        next if !defined $v;
        push @vals, "${k}::$v";
    }

    if (@vals == 0) {
        return '';
    }

    if (@vals == 1) {
        return $vals[0];
    }

    return "(" . join('&', @vals) . ")";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
