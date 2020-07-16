package pfappserver::Form::Config::Pfmon;

=head1 NAME

pfappserver::Form::Config::Pfmon - Web form for maintenance.conf

=head1 DESCRIPTION

Form definition to update an pfmon tasks

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';
use pf::config::pfmon qw(%ConfigMaintenanceDefault);

use Exporter qw(import);
our @EXPORT_OK = qw(default_field_method batch_help_text timeout_help_text window_help_text);
use pf::log;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Pfmon Name',
   required => 1,
   messages => { required => 'Please specify the name of the maintenance task' },
  );

has_field 'description' =>
  (
   type => 'Text',
   inactive => 1,
  );

has_field 'type' =>
  (
   type => 'Hidden',
   required => 1,
  );

has_field 'status' =>
  (
   type => 'Toggle',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default_method => \&default_field_method,
    tags => { after_element => \&help,
             help => 'Whether or not this task is enabled.<br>Requires a restart of pfmaint to be effective.' },
  );

has_field 'schedule' =>
  (
   type => 'Text',
   default_method => \&default_field_method,
    tags => { after_element => \&help,
             help => 'The schedule for maintenance task (cron like spec).' },
  );

has_block  definition =>
  (
    render_list => [qw(type status interval)],
  );

sub default_field_method {
    my ($field) = @_;
    my $name = $field->name;
    my $task_name = ref($field->form);
    $task_name =~ s/^pfappserver::Form::Config::Pfmon:://;
    my $value = $ConfigMaintenanceDefault{$task_name}{$name};
    if ($field->has_inflate_default_method) {
        $value = $field->inflate_default($value);
    }

    return $value;
}

sub batch_help_text { "Amount of items that will be processed in each batch of this task. Batches are executed until there is no more items to process or until the timeout is reached." }

sub timeout_help_text { "Maximum amount of time this task can run." }

sub window_help_text { "Window to apply the job to. In the case of a deletion, setting this to 7 days would delete affected data older than 7 days." }

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
