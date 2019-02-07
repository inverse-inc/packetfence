package captiveportal::PacketFence::DynamicRouting::Module::Survey;

=head1 NAME

captiveportal::DynamicRouting::Module::Survey

=head1 DESCRIPTION

Base Survey module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';
with 'captiveportal::Role::FieldValidation';

use Tie::IxHash;
use List::MoreUtils qw(uniq);
use pf::constants qw($FALSE $TRUE);
use pf::util;
use pf::log;
use pf::factory::survey;
use captiveportal::Form::Survey;
use pf::locationlog;
use pf::person qw(person_view);

has 'survey_id' => (is => 'rw', isa => 'Str');

has 'survey' => (is => 'rw', isa => 'pf::Survey', builder => '_build_survey', lazy => 1);

has 'required_fields' => (is => 'rw', isa => 'ArrayRef[Str]', builder => '_build_required_fields', lazy => 1);

has 'request_fields' => (is => 'rw', traits => ['Hash'], builder => '_build_request_fields', lazy => 1);

has 'template' => ('is' => 'rw', default => sub {'survey.html'});

sub continuous_survey_id {
    my ($self, $set) = @_;
    my $key = $self->survey->table_name . "-continuous-survey-id";
    if(defined($set)) {
        $self->app->session->{$key} = $set;
    }
    else {
        return $self->app->session->{$key};
    }
}

=head2 allowed_urls

The URLs that are allowed

=cut

sub allowed_urls {
    my ($self) = @_;
    return [
        '/signup',
    ];
}

=head2 form

The form for this module

=cut

sub form {
    my ($self) = @_;
    my $params = defined($self->app->request->parameters()) ? $self->app->request->parameters() : {};
    my $i18n = captiveportal::Base::I18N->new;
    my $form = captiveportal::Form::Survey->new(language_handle => $i18n, app => $self->app, module => $self, survey => $self->survey);
    $form->process(params => $params);
    return $form;
}

=head2 _build_request_fields

Builder for the request fields

=cut

sub _build_request_fields {
    my ($self) = @_;
    return $self->app->hashed_params()->{fields} || {};
}

=head2 _build_source

Builder for the source using the source_id attribute

=cut

sub _build_survey {
    my ($self) = @_;
    $self->survey(pf::factory::survey->new($self->{survey_id}));
}

=head2 _build_required_fields

Build the required fields based on the PID field, the custom fields and the mandatory fields of the source

=cut

sub _build_required_fields {
    my ($self) = @_;
    my @fields = map { isenabled($self->survey->{fields}->{$_}->{required}) ? $_ : () } keys(%{$self->survey->{fields}});
    return [@fields];
}

=head2 merged_fields

Merge the required fields with the values provided in the request

=cut

sub merged_fields {
    my ($self) = @_;
    tie my %merged, 'Tie::IxHash';
    foreach my $field (@{$self->survey->fields_order}){
        $merged{$field} = $self->request_fields->{$field};
    }
    return \%merged;
}

=head2 prompt_fields

Prompt for the necessary fields

=cut

sub prompt_fields {
    my ($self, $args) = @_;
    $args //= {};
    $self->render($self->template, {
        previous_request => $self->app->request->parameters(),
        fields_order => $self->survey->fields_order,
        fields => $self->merged_fields,
        form => $self->form,
        title => defined($self->survey) ? $self->survey->description : "Survey",
        %{$args},
    });
}

sub execute_child {
    my ($self) = @_;
    # If there is no fields to prompt or we're handling a form POST
    if(!@{$self->survey->fields_order} || $self->app->request->method eq "POST") {
        if(my $id = $self->survey->insert_or_update_response($self->merged_fields, { 
                    node => $self->node_info, 
                    ip => $self->current_ip, 
                    person => person_view($self->username), 
                    profile => $self->app->profile,
                    survey => $self->survey,
                }, $self->continuous_survey_id)) {
            # Set the continious survey ID if its not already set
            $self->continuous_survey_id($id) unless(defined($self->continuous_survey_id()));

            $self->done();
        }
        else {
            $self->app->error("Failed to record your response. Please try again later.");
        }
    }
    else {
        $self->prompt_fields();
    }
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

