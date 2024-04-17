package pfappserver::Form::Config::Pfcron::pfflow;

=head1 NAME

pfappserver::Form::Config::Pfcron::pfflow -

=head1 DESCRIPTION

pfappserver::Form::Config::Pfcron::pfflow

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose;

use pfappserver::Form::Config::Pfcron qw(default_field_method batch_help_text);

extends 'pfappserver::Form::Config::Pfcron';
with 'pfappserver::Base::Form::Role::Help';

has_field 'kafka_brokers' => (
    type => 'Text',
    default_method => \&default_field_method,
    tags => { help => 'Kafka Brokers' },
);

has_field 'read_topic' => (
    type => 'Text',
    default_method => \&default_field_method,
    tags => { help => 'The Kafka topic to read pfflows from' },
);

has_field 'send_topic' => (
    type => 'Text',
    default_method => \&default_field_method,
    tags => { help => 'The Kafka topic to write network events to' },
);

has_field 'group_id' => (
    type => 'Text',
    default_method => \&default_field_method,
    tags => { help => 'The Kafka Consumer Group ID ' },
);

has_field 'submit_batch' => (
    type => 'PosInteger',
    default_method => \&default_field_method,
    tags => { after_element => \&help,
             help => \&batch_help_text },
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
