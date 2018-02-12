package pfappserver::Form::Config::Syslog;

=head1 NAME

pfappserver::Form::Config::Syslog - Web form for an admin role

=head1 DESCRIPTION

Form definition to create or update an admin role

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';
use pf::constants::syslog;

use pf::log;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Syslog Name',
   required => 1,
   messages => { required => 'Please specify the name of the Syslog entry' },
  );

has_field type => (
    type => 'Hidden',
    required => 1,
    default_method => \&default_type,
);

has_field all_logs => (
    type => 'Checkbox',
    input_without_param => 'disabled',
    checkbox_value => 'enabled',
    default => 'enabled',
);

has_field 'logs' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Logs',
   options_method => \&available_log_options,
   default_method => \&default_logs,
   element_class => [qw(chzn-select input-xxlarge)],
   element_attr => {'data-placeholder' => 'Click to add a log'},
   tags => { after_element => \&help,
             help => 'Logs' },
  );

has_block  definition =>
  (
    render_list => [qw(type all_logs logs)],
  );

=head2 default_logs

Return the default logs

=cut

sub default_logs {
    [ map { $_->{name} } @pf::constants::syslog::SyslogInfo ];
}

=head2 available_log_options

Return the list of available log options

=cut

sub available_log_options {
    return map { { label => $_, value => $_ } } @{default_logs()};
}

=head2 default_type

Returns the default type of the Syslog forwarder

=cut

sub default_type {
    my ($self) = @_;
    my $type = ref($self);
    $type =~ s/^pfappserver::Form::Config::Syslog:://;
    return $type;
}

=head2 html_attributes

html_attributes

=cut

sub html_attributes {
    my ( $self, $obj, $type, $attrs, $result ) = @_;
    $attrs = $self->SUPER::html_attributes($obj, $type, $attrs, $result);
    if ($type eq 'wrapper' && $obj->name eq 'logs') {
        if ($self->field('all_logs')->value eq 'enabled') {
            push @{$attrs->{class}}, 'hidden';
        }
    }
    return $attrs;
}

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;
