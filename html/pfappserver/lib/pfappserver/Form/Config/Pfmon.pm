package pfappserver::Form::Config::Pfmon;

=head1 NAME

pfappserver::Form::Config::Pfmon - Web form for an admin role

=head1 DESCRIPTION

Form definition to create or update an admin role

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';
use pf::config::pfmon qw(%ConfigPfmonDefault);

use Exporter qw(import);
our @EXPORT_OK = qw(default_field_method);
use pf::log;

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Pfmon Name',
   required => 1,
   messages => { required => 'Please specify the name of the pfmon entry' },
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
  );

has_field 'interval' =>
  (
   type => 'Duration',
   default_method => \&default_field_method,
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
    return $ConfigPfmonDefault{$task_name}{$name};
}

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
