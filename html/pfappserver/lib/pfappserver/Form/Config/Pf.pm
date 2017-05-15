package pfappserver::Form::Config::Pf;

=head1 NAME

pfappserver::Form::Config::Pf - Web form for pf.conf

=head1 DESCRIPTION

Form definition to create or update a section of pf.conf.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';
with 'pfappserver::Base::Form::Role::Defaults';
use pf::config qw(%Default_Config %Doc_Config);
use pf::log;
use pf::IniFiles;
use pf::file_paths qw($pf_default_file);
use pf::authentication;
use pf::web::util;

has 'section' => ( is => 'ro' );


=head2 field_list

Dynamically build the field list from the 'section' instance attribute.

=cut

sub field_list {
    my $self = shift;

    my $list = [];
    my $section = $self->section;
    my $default_pf_config = pf::IniFiles->new(-file => $pf_default_file, -allowempty => 1);
    my @section_fields = $default_pf_config->Parameters($section);
    foreach my $name (@section_fields) {
        my $doc_section_name = "$section.$name";
        my $doc_section = $Doc_Config{$doc_section_name};
        my $defaults = $Default_Config{$section};
        $doc_section->{description} =~ s/\n//sg;
        my $doc_anchor = $doc_section->{guide_anchor};
        my $doc_anchor_html = defined($doc_anchor) ? " " . pf::web::util::generate_doc_link($doc_anchor) . " " : '';
        my $field =
          { element_attr => { 'placeholder' => $defaults->{$name} },
            tags => { after_element => \&help, # role method, defined in Base::Form::Role::Help
                      help => $doc_section->{description} . $doc_anchor_html },
            id => $name,
            label => $doc_section_name,
            type => 'Text',
          };
        my $type = $doc_section->{type} || "text";
        #skip if hidden
        next if $type eq 'hidden';
        {

            ($type eq "text" && $doc_section->{description} =~ m/comma[-\s](delimite|separate)/si) && do {
                $type = 'text-large';
            };
            $type eq 'text' && do {
                $field->{type} = 'Text';
                last;
            };
            $type eq 'text-large' && do {
                $field->{type} = 'TextArea';
                $field->{element_class} = ['input-xxlarge'];
                last;
            };
            $type eq 'text_with_editable_default' && do {
                $field->{type} = 'Text';
                $field->{default} = $defaults->{$name};
                last;
            };
            $type eq 'list' && do {
                $field->{type} = 'TextArea';
                $field->{element_class} = ['input-xxlarge'];
                # NOTE: line feeds in placeholder attribute are ignored, so we keep the commas and set
                # the value to the default value when no value is defined (see pf::ConfigStore::Pf::cleanupAfterRead)
                # $field->{element_attr}->{placeholder} = join("\n",split( /\s*,\s*/, $field->{element_attr}->{placeholder} ))
                #   if $field->{element_attr}->{placeholder};
                last;
            };
            $type eq 'fingerbank_list' && do {
                $field->{type} = 'FingerbankSelect';
                $field->{element_class} = ['input-xxlarge'];
                last;
            };
            $type eq 'merged_list' && do {
                delete $field->{element_attr}->{placeholder};
                $field->{tags}->{before_element} = \&defaults_list;
                $field->{tags}->{defaults} = $defaults->{$name};
                $field->{type} = 'TextArea';
                $field->{element_class} = ['input-xxlarge'];
                last;
            };
            $type eq 'numeric' && do {
                $field->{type} = 'PosInteger';
                if (exists $doc_section->{minimum}) {
                    my $minimum = $doc_section->{minimum};
                    $field->{apply} = [{
                            check   => sub {$_[0] >= $minimum},
                            message => sub {
                                my ($value, $field) = @_;
                                return $field->name . " must be greater or equal to $minimum";
                            },
                        }];
                }
                last;
            };
            $type eq 'hex' && do {
                    $field->{apply} = [{
                            check   => sub {$_[0]  =~ /^[0-9a-fA-F]+$/},
                            message => sub {
                                my ($value, $field) = @_;
                                return $field->name . " must be hexadecimal";
                            },
                        }];
                last;
            };
            $type eq 'multi' && do {
                $field->{type} = 'Select';
                $field->{multiple} = 1;
                $field->{element_class} = ['chzn-select', 'input-xxlarge'];
                $field->{element_attr} = {'data-placeholder' => 'Click to add'};
                my @options = map { { value => $_, label => $_ } } @{$doc_section->{options}};
                $field->{options} = \@options;
                last;
            };
            $type eq 'role' && do {
                $field->{type} = 'Select';
                $field->{element_class} = ['chzn-deselect', 'input'];
                $field->{element_attr} = {'data-placeholder' => 'Select a role'};
                my $roles = $self->ctx->model('Config::Roles')->listFromDB();
                my @options = ({ value => '', label => ''}, map { { value => $_->{name}, label => $_->{name} } } @$roles);
                $field->{options} = \@options;
                last;
            };
            $type eq 'toggle' && do {
                if ($doc_section->{options}->[0] eq 'enabled' ||
                    $doc_section->{options}->[0] eq 'yes') {
                    $field->{type} = 'Toggle';
                    $field->{checkbox_value} = $doc_section->{options}->[0];
                    $field->{unchecked_value} = $doc_section->{options}->[1];
                }
                else {
                    $field->{type} = 'Select';
                    $field->{element_class} = ['chzn-deselect'];
                    $field->{element_attr} = {'data-placeholder' => 'No selection'};
                    my @options = map { { value => $_, label => $_ } } @{$doc_section->{options}};
                    $field->{options} = \@options;
                }
                last;
            };
            $type eq 'date' && do {
                $field->{type} = 'DatePicker';
                last;
            };
            $type eq 'time' && do {
                $field->{type} = 'Duration';
                last;
            };
            $type eq 'extended_time' && do {
                $field->{type} = 'Text';
                push(@$list, $name => $field);

                # We currently have a single "extended_time" parameter and it's [guests_admin_registration.default_access_duration]
                $name .= "_add";
                $field =
                  {
                   id => $name,
                   label => 'Duration',
                   type => 'ExtendedDuration',
                   no_value => 1,
                   wrapper_class => ['compound-input-btn-group', 'extended-duration', 'well'],
                   tags => { after_element => '<div class="controls"><a href="#" id="addExtendedTime" class="btn btn-info" data-target="#access_duration_choices">' . $self->_localize("Add to Duration Choices") . '</a>' }
                  };
                last;
            };
            $type eq 'email' && do {
                $field->{type} = 'Email';
                last;
            };
            $type eq 'obfuscated' && do {
                $field->{type} = 'ObfuscatedText';
                last;
            };
            $type eq 'sms_sources' && do {
                $field->{type} = 'Select';
                $field->{element_class} = ['chzn-deselect'];
                $field->{element_attr} = {'data-placeholder' => 'No selection'};
                my @options = ({value => '', label => 'None' }, map { { value => $_, label => $_ } } get_sms_source_ids());
                $field->{options} = \@options;
            }
        }
        if ($field->{type} eq 'Text') {
            if (exists $doc_section->{minimum_length}) {
                my $minimum_length = $doc_section->{minimum_length};
                push(
                    @{$field->{apply}},
                    {
                        check   => sub {length($_[0]) >= $minimum_length},
                        message => sub {
                            my ($value, $field) = @_;
                            return $field->name . " must be greater or equal to $minimum_length";
                        },
                    });
            }
            if (exists $doc_section->{maximum_length}) {
                my $maximum_length = $doc_section->{maximum_length};
                push(
                    @{$field->{apply}},
                    {
                        check   => sub {length($_[0]) <= $maximum_length},
                        message => sub {
                            my ($value, $field) = @_;
                            return $field->name . " must be greater or equal to $maximum_length";

                        },
                    });
            }
        }
        push(@$list, $name => $field);
    }
    return $list;
}


=head2 get_sms_source_ids

get_sms_source_ids

=cut

sub get_sms_source_ids {
    return map { $_->id } grep { $_->can("sendSMS") } @{getAllAuthenticationSources()};
}

#sub validate {
#    my $self = shift;
#
#    foreach my $section (keys %{$self->value}) {
#        foreach my $field (keys %{$self->value->{$section}}) {
#            my $new_field = $field;
#            $new_field =~ s/::dot::/\./g;
#            $self->value->{$section}->{$new_field}
#              = delete $self->value->{$section}->{$field};
#        }
#    }
#}

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
