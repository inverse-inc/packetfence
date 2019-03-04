package pfappserver::Form::Config::Scan::Rapid7;

=head1 NAME

pfappserver::Form::Config::Scan::Rapid7 - Web form to add a Rapid7 Scan Engine

=head1 DESCRIPTION

Form definition to create or update a Rapid7 Scan Engine.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Scan';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
);

use pf::config;
use pf::util;
use File::Find qw(find);

has_field 'type' =>
  (
   type => 'Hidden',
  );

has_field 'host' =>
  (
   type => 'Text',
   label => 'Hostname or IP Address',
   required => 1,
   messages => { required => 'Please specify the hostname or IP of the scan engine' },
  );

has_field 'port' =>
  (
   type => 'PosInteger',
   label => 'Port of the API',
   tags => { after_element => \&help,
             help => 'If you use an alternative port, please specify' },
   default => 3780,
  );

has_field 'template_id' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'Scan template',
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to select a scan template'},
   tags => { after_element => \&help,
             help => 'The scan template to use for scanning the clients.' },
  );

has_field 'site_id' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'Site',
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to select a site'},
   tags => { after_element => \&help,
             help => 'The identifier of the site to scan (the site where the hosts are located)' },
  );


has_field 'engine_id' =>
  (
   type => 'Select',
   multiple => 0,
   label => 'Scan Engine',
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to select an engine'},
   tags => { after_element => \&help,
             help => 'The identifier of the scan engine to use when scanning the devices.' },
  );

  has_field 'verify_hostname' =>
  (
   type => 'Toggle',
   label => 'Verify Hostname',
   tags => { after_element => \&help,
             help => 'Verify hostname of server when connecting to the API' },
   checkbox_value  => 'enabled',
   unchecked_value => 'disabled',
   default => 'enabled',
  );

has_block definition =>
  (
   render_list => [ qw(id type username password host port verify_hostname engine_id template_id site_id categories oses duration pre_registration registration post_registration) ],
  );

around 'process' => sub {
    my $sub = shift;
    my @args = @_;

    my ($form, $context, $params) = @args;
    
    my $scan;
    eval {
        $scan = pf::factory::scan->new($params->{id});
    };
    
    my %sub_map = (
        engine_id => sub {$scan->listScanEngines},
        template_id => sub {$scan->listScanTemplates},
        site_id => sub {$scan->listSites},
    );

    foreach my $field_name (qw(engine_id template_id site_id)) {
        my $field = $form->field($field_name);
        if($scan) {
            my $values = $sub_map{$field_name}->();
            if(defined($values)) {
                my @options = map{ {label => $_->{name}, value => $_->{id}} } @$values;
                $field->options(\@options);
            }
            else {
                $field->options([{label => $params->{$field_name}, value => $params->{$field_name}}]);
                $field->disabled(1);
                $field->tags->{help} = "There was an error communicating with Rapid7. Check server side logs or retry later to be able to edit this field.";
            }
        }
        else {
            $field->options([{label => $params->{$field_name}, value => $params->{$field_name}}]);
            $field->disabled(1);
            $field->tags->{help} = "After configuring this scan engine for the first time, you will be able to select this attribute from the available ones in Rapid7.";
        }
    }

    $sub->(@args);
};

=over

=back

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
