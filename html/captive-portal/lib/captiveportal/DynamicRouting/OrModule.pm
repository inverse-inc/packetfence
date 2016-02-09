package captiveportal::DynamicRouting::OrModule;

=head1 NAME

captiveportal::DynamicRouting::OrModule

=head1 DESCRIPTION

For giving a choice between multiple modules

=cut

use Moose;
extends 'captiveportal::DynamicRouting::ModuleManager';

sub next {
    my ($self) = @_;
    $self->done();
}

before 'execute_child' => sub {
    my ($self) = @_;
    if($self->app->request->path =~ /^switchto\/(.+)/){
        $self->current_module($1) if($self->module_map->{$1});
    }
};

sub render {
    my ($self, @params) = @_;
    my $inner_content = $self->app->_render(@params);
    $self->SUPER::render('content-with-choice.html', {content => $inner_content, modules => [$self->all_modules], current_module => $self->current_module});
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

__PACKAGE__->meta->make_immutable;

1;

