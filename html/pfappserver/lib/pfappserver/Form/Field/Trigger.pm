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
use pf::constants::trigger;

has_field $TRIGGER_TYPE_ACCOUNTING => (
	type => 'Text',
);

has_field $TRIGGER_TYPE_DETECT => (
	type => 'Text',
);

has_field $TRIGGER_TYPE_MAC => (
	type => 'Text',
);

has_field $TRIGGER_TYPE_NESSUS => (
	type => 'Text',
);

has_field $TRIGGER_TYPE_OPENVAS => (
	type => 'Text',
);

has_field $TRIGGER_TYPE_OS => (
	type => 'Text',
);

has_field $TRIGGER_TYPE_USERAGENT => (
	type => 'Text',
);

has_field $TRIGGER_TYPE_VENDORMAC => (
	type => 'Text',
);

has_field $TRIGGER_ID_PROVISIONER => (
	type => 'Text',
);

while (my ($trigger, $value) = each %$TRIGGER_MAP) {
    has_field $trigger => (
        type => 'Select',
        options => sub {
            return map { { label => $_, value => $_ } } keys %value;
        },
    );
}

=head2 options_suricata_event

options_suricata_event

=cut

sub options_suricata_event {
    map { { label => $_, value => $_ } } keys %$SURICATA_CATEGORIES;
}

=head2 options_switch

options_switch

=cut

sub options_switch {
    return ;
}

=head2 options_switch_group

options_switch_group

=cut

sub options_switch_group {
    return ;
}

=head2 options_nessus

options_nessus

=cut

sub options_nessus {
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
