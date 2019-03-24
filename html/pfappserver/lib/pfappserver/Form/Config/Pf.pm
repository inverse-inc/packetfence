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
use fingerbank::Model::Device;
# For passthroughs validation
use pf::util::dns;
use pfconfig::namespaces::resource::passthroughs;
use pfconfig::namespaces::resource::isolation_passthroughs;
#For Input Validation/Sanitization
use Input::Validation;

has 'section' => ( is => 'ro' );

=head2 field_list

Dynamically build the field list from the 'section' instance attribute.

=cut

sub field_list {
    my $self = shift;
    my ($list , $section) = ([] , $self->section);
    return [] if !defined $section;
    my $default_pf_config = pf::IniFiles->new(-file => $pf_default_file, -allowempty => 1);
    my @section_fields = $default_pf_config->Parameters($section);

    foreach my $name (@section_fields) {
        my $doc_section_name = "$section.$name";
        my $doc_section = $Doc_Config{$doc_section_name};
        my $defaults = $Default_Config{$section};
        $doc_section->{description} //= '';
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

        next if $type eq 'hidden'; #skip if hidden
        {
            my $exec;
            $exec = {
                'text' => sub {
                    return ($exec->{'text-large'}->()) if($doc_section->{description} =~ m/comma[-\s](delimite|separate)/si);
                    $field->{type} = 'Text';
                    if ( (exists $doc_section->{minimum_length}) && (my $minimum_length = $doc_section->{minimum_length}) ) {
                        push( @{$field->{apply}},
                            {
                                check   => sub {length($_[0]) >= $minimum_length},
                                message => sub {
                                    my ($value, $field) = @_;
                                    return $field->name . " must be greater or equal to $minimum_length";
                                },
                            });
                    }
                    if ( (exists $doc_section->{maximum_length}) && (my $maximum_length = $doc_section->{maximum_length}) ) {
                        push( @{$field->{apply}},
                            {
                                check   => sub {length($_[0]) <= $maximum_length},
                                message => sub {
                                    my ($value, $field) = @_;
                                    return $field->name . " must be greater or equal to $maximum_length";
                                },
                            });
                    } 
                },
                'ipaddr' => sub { 
                    $field->{type} = 'IPAddress';
                },
                'path' => sub { 
                    $field->{type} = 'Path';
                },
                'text-large' => sub { 
                    $field->{type} = 'TextArea';
                    $field->{element_class} = ['input-xxlarge'];
                },
                'text_with_editable_default' => sub {
                    $field->{type} = 'Text';
                    $field->{default} = $defaults->{$name};
                },
                'list' => sub { 
                    $field->{type} = 'TextArea';
                    $field->{element_class} = ['input-xxlarge'];
                    # NOTE: line feeds in placeholder attribute are ignored, so we keep the commas and set
                    # the value to the default value when no value is defined (see pf::ConfigStore::Pf::cleanupAfterRead)
                    # $field->{element_attr}->{placeholder} = join("\n",split( /\s*,\s*/, $field->{element_attr}->{placeholder} ))
                    #   if $field->{element_attr}->{placeholder};   
                 },
                'fingerbank_select' => sub { 
                    $field->{type} = 'FingerbankSelect';
                    $field->{multiple} = 1;
                    $field->{element_class} = ['chzn-deselect'];
                    $field->{element_attr} = {'data-placeholder' => 'Click to add an OS'};
                    $field->{fingerbank_model} = 'fingerbank::Model::Device';
                 },
                'fingerbank_device_transition' => sub { 
                    $field->{type} = 'TextArea';
                    $field->{element_class} = ['input-xxlarge'];
                    my @devices = map { 
                        my (undef, $device) = fingerbank::Model::Device->read($_); 
                        {name => $device->name, id => $_}
                    } @{fingerbank::Model::Device->all_device_class_ids};
                    @devices = sort {lc($a->{name}) cmp lc($b->{name})} @devices;
                    my $str = "";
                    $str .= "<ul>";
                    $str .= join("", map{ '<li><b>' . $_->{name} . '</b>' . " = " . $_->{id} . "</li>" } @devices); 
                    $str .= "</ul>";
                    $field->{tags}->{help} .= "<br><br>Valid device classes IDs are: $str";
                 },
                'merged_list' => sub { 
                    delete $field->{element_attr}->{placeholder};
                    $field->{tags}->{before_element} = \&defaults_list;
                    $field->{tags}->{defaults} = $defaults->{$name};
                    $field->{type} = 'TextArea';
                    $field->{element_class} = ['input-xxlarge'];
                 },
                'numeric' => sub { 
                    $field->{type} = 'PosInteger';
                    if ( (exists $doc_section->{minimum}) && (my $minimum = $doc_section->{minimum}) ) {
                        $field->{apply} = [{
                                check   => sub {$_[0] >= $minimum},
                                message => sub {
                                    my ($value, $field) = @_;
                                    return $field->name . " must be greater or equal to $minimum";
                                },
                            }];
                    }
                    if ( (exists $doc_section->{maximum}) && (my $maximum = $doc_section->{maximum}) ) {
                        $field->{apply} = [{
                                check   => sub {$_[0] <= $maximum},
                                message => sub {
                                    my ($value, $field) = @_;
                                    return $field->name . " must be smaller or equal to $maximum";
                                },
                            }];
                    }
                 },
                'hex' => sub { 
                    $field->{apply} = [{
                            check   => sub {$_[0]  =~ /^[0-9a-fA-F]+$/},
                            message => sub {
                                my ($value, $field) = @_;
                                return $field->name . " must be hexadecimal";
                            },
                        }];
                 },
                'multi' => sub { 
                    $field->{type} = 'Select';
                    $field->{multiple} = 1;
                    $field->{element_class} = ['chzn-select', 'input-xxlarge'];
                    $field->{element_attr} = {'data-placeholder' => 'Click to add'};
                    my @options = map { { value => $_, label => $_ } } @{$doc_section->{options}};
                    $field->{options} = \@options;
                 },
                'role' => sub { 
                    $field->{type} = 'Select';
                    $field->{element_class} = ['chzn-deselect', 'input'];
                    $field->{element_attr} = {'data-placeholder' => 'Select a role'};
                    my $roles = $self->ctx->model('Config::Roles')->listFromDB();
                    my @options = ({ value => '', label => ''}, map { { value => $_->{name}, label => $_->{name} } } @$roles);
                    $field->{options} = \@options;
                 },
                'timezone' => sub { 
                    $field->{type} = 'Select';
                    $field->{element_class} = ['chzn-deselect'];
                    $field->{element_attr} = {'data-placeholder' => 'Select a timezone'};
                    my @timezones = DateTime::TimeZone->all_names();
                    my @matched_options = map { m/^.+\/.+$/g } @timezones;
                    my @options = ({ value => '', label => ''}, map { { value => $_, label => $_ } } @matched_options);
                    $field->{options} = \@options;
                 },
                'toggle' => sub { 
                    if ($doc_section->{options}->[0] eq 'enabled' || $doc_section->{options}->[0] eq 'yes') {
                        $field->{type} = 'Toggle';
                        $field->{checkbox_value} = $doc_section->{options}->[0];
                        $field->{unchecked_value} = $doc_section->{options}->[1];
                    }else {
                        $field->{type} = 'Select';
                        $field->{element_class} = ['chzn-deselect'];
                        $field->{element_attr} = {'data-placeholder' => 'No selection'};
                        my @options = map { { value => $_, label => $_ } } @{$doc_section->{options}};
                        $field->{options} = \@options;
                    }
                 },
                'date' => sub { 
                    $field->{type} = 'DatePicker';
                 },
                'time' => sub { 
                    $field->{type} = 'Duration';
                 },
                'extended_time' => sub { 
                    $field->{type} = 'Text';
                    push(@$list, $name => $field);
                    # We currently have a single "extended_time" parameter and it's [guests_admin_registration.default_access_duration]
                    $name .= "_add";
                    $field = {
                    id => $name,
                    label => 'Duration',
                    type => 'ExtendedDuration',
                    no_value => 1,
                    wrapper_class => ['compound-input-btn-group', 'extended-duration', 'well'],
                    tags => { after_element => '<div class="controls"><a href="#" id="addExtendedTime" class="btn btn-info" data-target="#access_duration_choices">' . $self->_localize("Add to Duration Choices") . '</a>' }
                    };
                 },
                'email' => sub { 
                    $field->{type} = 'Email';
                 },
                'obfuscated' => sub { 
                    $field->{type} = 'ObfuscatedText';
                 },
                'sms_sources' => sub { 
                    $field->{type} = 'Select';
                    $field->{element_class} = ['chzn-deselect'];
                    $field->{element_attr} = {'data-placeholder' => 'No selection'};
                    my @options = ({value => '', label => 'None' }, map { { value => $_, label => $_ } } get_sms_source_ids());
                    $field->{options} = \@options;
                 },
                'default' => sub { 
                    return ($exec->{'text'}->()); 
                 },
            };

            ($exec->{$type} || $exec->{'default'})->();
        }
        if (my $validate_method = $self->validator_for_field($doc_section_name)) {
            $field->{validate_method} = $validate_method;
        }
        push(@$list, $name => $field);
    }
    return $list;
}

our %FIELD_VALIDATORS = (
    "general.hostname" => sub { 
        form_field_validation('hostname', 1 , @_);
        validate_fqdn_not_in_passthroughs(@_, [ "passthroughs", "isolation_passthroughs" ]);
        },
    "general.domain" => sub { 
        validate_pf_domain(@_);
        validate_fqdn_not_in_passthroughs(@_, [ "passthroughs", "isolation_passthroughs" ]);
        },
    "fencing.passthroughs" => sub { 
        validate_fqdn_not_in_passthroughs(@_, ["passthroughs"]);
        },
    "fencing.isolation_passthroughs" => sub { 
        validate_fqdn_not_in_passthroughs(@_, ["isolation_passthroughs"]);
        },
    "alerting.emailaddr" => sub { 
        form_field_validation('email' , 0 ,@_); 
        },
    "alerting.smtpserver" => sub { 
        form_field_validation('hostname||ip', 0 , @_);
        },
    "database.host" => sub { 
        form_field_validation('hostname||ip', 1 , @_);
        },
    "general.dhcpservers" => sub { 
        form_field_validation('hostname||ip' , 0 ,@_);
        },
    "fencing.whitelist" => sub { 
        form_field_validation('mac' , 0 ,@_);
        },
    "fencing.passthroughs" => sub { 
        form_field_validation('domain' , 0 ,@_);
        },
    "fencing.proxy_passthroughs" => sub { 
        form_field_validation('domain' , 0 ,@_);
        },
    "fencing.isolation_passthroughs" => sub { 
        form_field_validation('domain' , 0 ,@_);
        },
    "fencing.interception_proxy_port" => sub { 
        form_field_validation('port' , 0 ,@_);
        },
    "captive_portal.loadbalancers_ip" => sub { 
        form_field_validation('ip' , 0 ,@_);
        },
    "captive_portal.other_domain_names" => sub { 
        form_field_validation('domain' , 0 ,@_);
        },
);

=head2 validator_for_field

Get the validator for a field

=cut

sub validator_for_field {
    my ($self, $field) = @_;
    return $FIELD_VALIDATORS{$field};
}

=head2 validate_pf_domain

Validate that the domain name is valid and doesn't end with .local (iOS popup bug)

=cut


sub validate_pf_domain {
    my (undef, $field) = @_;
    my $domain = $field->value;
    form_field_validation('domain' , 1 ,$field);
    return ($field->add_error("The domain name cannot end with '.local' as this causes issues with Apple iOS devices")) if ($domain =~ /\.local$/);
}

=head2 validate_fqdn_field

For an FQDN, this validates that its not part of the passthroughs

=cut

=head2 validate_passthroughs_field

For a passthrough form field, this validates that the passthroughs it contains won't match the portal FQDN

=cut

sub validate_fqdn_not_in_passthroughs {
    my (undef, $field, $modules) = @_; 
    get_logger->debug("Validating field ".$field->name);
    my $cs = pf::ConfigStore::Pf->new;
    my ($general , $fencing , $params) = ($cs->read("general") , $cs->read("fencing") , $field->form->params);

    # Use the hostname + domain from the form if its there, otherwise, restore it from the ConfigStore
    my ($hostname , $domain) = ($params->{hostname} // $general->{hostname} , $params->{domain} // $general->{domain} );
    my $fqdn = "$hostname.$domain";

    get_logger->debug("Validating passthroughs using FQDN $fqdn");

    for my $module (@$modules) {
        my $passthroughs_txt = [ split(/\r?\n/, (defined($params->{$module}) ? $params->{$module} : $fencing->{$module})) ];
        get_logger->debug("Validating FQDN against passthroughs: " . join(",", @$passthroughs_txt));

        my $passthroughs = "pfconfig::namespaces::resource::$module"->_build($passthroughs_txt);
        my ($res, undef) = pf::util::dns::_matches_passthrough($passthroughs, $fqdn);

        if($res) {
            $field->add_error("Passthroughs cannot contain the portal FQDN ($fqdn) or any wildcard for this domain");
        }
    }
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
