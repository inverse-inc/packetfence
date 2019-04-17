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

use pf::constants::trigger qw($TRIGGER_MAP);
use pf::factory::condition::security_event;
use pf::ConfigStore::Roles;

our %SKIPPED = (
    role => 1,
    device => 1,
);

for my $trigger (keys %pf::factory::condition::security_event::TRIGGER_TYPE_TO_CONDITION_TYPE) {
    next if exists $SKIPPED{$trigger};
    if (exists $TRIGGER_MAP->{$trigger}) {
        my $value = $TRIGGER_MAP->{$trigger};
        has_field $trigger => (
            type => 'Select',
            options_method => sub {
                return map { { label => $_, value => $_ } } keys %$value;
            },
        );
    } else {
        has_field $trigger => (
            type => 'Text'
        );
    }
}

has_field 'role' => (
    type => 'Select',
    options_method => sub {
        return map { { label => $_, value => $_ } } @{pf::ConfigStore::Roles->new->readAllIds()};
    },
);

has_field 'device' => (
   type => 'FingerbankSelect',
   multiple => 1,
   label => 'OS',
   fingerbank_model => "fingerbank::Model::Device",
);


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
        if (ref($v) eq 'ARRAY') {
            next if @$v == 0;
            $v = join (',', @$v);
        }

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
