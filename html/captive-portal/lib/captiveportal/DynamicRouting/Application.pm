package captiveportal::DynamicRouting::Application;

=head1 NAME

DynamicRouting::Application

=head1 DESCRIPTION

Application definition for Dynamic Routing

=cut

use Moose;
with 'captiveportal::DynamicRouting::ModuleManager';

use Template::AutoFilter;
use pf::log;

has 'session' => (is => 'rw', required => 1);

has 'root_module' => (is => 'rw');

has 'request' => (is => 'ro', required => 1);

has 'hashed_params' => (is => 'rw');

has 'profile' => (is => 'rw', required => 1, isa => "pf::Portal::Profile");

has 'template_output' => (is => 'rw');

sub BUILD {
    my ($self) = @_;
    my $hashed = {};
    my $request = $self->request;
    foreach my $param (keys %{$request->parameters}){
        if($param =~ /^(.+)\[(.+)\]$/){
            $hashed->{$1} //= {};
            $hashed->{$1}->{$2} = $request->parameters->{$param};
        }
        else {
            $hashed->{$param} = $request->parameters->{$param};
        }
    }
    $self->hashed_params($hashed);
};

sub rendering_map {
    return {
    };
}

sub set_current_module {
    my ($self, $module) = @_;
    $self->session->{current_module_id} = $module;
}

sub current_module_id {
    my ($self) = @_;
    $self->session->{current_module_id} //= $self->root_module->id;
    return $self->session->{current_module_id};
}

sub execute {
    my ($self) = @_;
    my $module = $self->find_module(sub { $_->id eq $self->current_module_id });
    die "Can't find current module" unless($module);
    $module->execute();
}

sub render {
    my ($self, $template, $args) = @_;


    my $inner_content = $self->_render($template,$args);

    my $content = $self->_render('layout.html', {content => $inner_content});

    $self->template_output($content);
}

sub _render {
    my ($self, $template, $args) = @_;
    
    get_logger->trace(sub { use Data::Dumper ; "Rendering template $template with args : ".Dumper($args)});
    
    our $TT_OPTIONS = {
        ABSOLUTE => 1, 
        AUTO_FILTER => 'html',
    };

    $args->{rendering_map} = $self->rendering_map;

    our $processor = Template::AutoFilter->new($TT_OPTIONS);;
    my $output = '';
    $processor->process("/usr/local/pf/html/captive-portal/new-templates/$template", $args, \$output) || die("Can't generate template $template: ".$processor->error);

    return $output;
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

