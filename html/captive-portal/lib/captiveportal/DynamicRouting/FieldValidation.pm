package captiveportal::DynamicRouting::FieldValidation;

=head1 NAME

captiveportal::DynamicRouting::FieldValidation

=head1 DESCRIPTION

Field Validation role

=cut

use Moose::Role;

around 'execute_child' => sub {
    my $orig = shift;
    my $self = shift;

    if($self->app->request->method eq "POST" && $self->app->request->path eq "signup"){
        if($self->handle_posted_fields()){
            return $self->$orig(@_);  
        }
        else {
            return;
        }
    }
    $self->$orig(@_);
};

sub validate_required_fields {
    my ($self) = @_;
    my @errors;
    foreach my $field (@{$self->required_fields}){
        unless(defined($self->request_fields->{$field})){
            push @errors, "$field is required";
        }
    }
    return \@errors;
}

sub validate_form {
    my ($self) = @_;

    my $errors = $self->validate_required_fields();
    if(@$errors){
        $self->app->flash->{error} = "The following errors prevented the request to be fulfilled : ".join(', ', @$errors);
        return 0;
    }
    my $form = $self->form($self->request_fields);
    if($form->has_errors){
        $self->app->flash->{error} = "An error occured while processing the request.";
        return 0;
    }
    return 1;
}

sub handle_posted_fields {
    my ($self) = @_;
    unless($self->validate_form()){
        $self->prompt_fields();
        return 0;
    }
    return 1;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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


