package pf::UnifiedApi::OpenAPI::Generator;

=head1 NAME

pf::UnifiedApi::OpenAPI::Generator

Generates the OpenAPI Path information for a controller and action

=cut

=head1 DESCRIPTION

pf::UnifiedApi::OpenAPI::Generator

=cut

use strict;
use warnings;
use Moo;
use Pod::Find qw(pod_where);
use Pod::Select qw(podselect);
use Pod::Markdown;
use Pod::Text;
use Lingua::EN::Inflexion qw(noun);

=head2 generatePath

generate the OpenAPI Path

=cut

sub generatePath {
    my ($self, $controller, $actions) = @_;
    my %path = $self->operations($controller, $actions);
    if (!keys %path) {
        return undef;
    }

    if (defined (my $summary = $self->summary($controller, $actions))) {
        $path{summary} = $summary
    }

    if (defined (my $description = $self->description($controller, $actions))) {
        $path{description} = $description
    }

    if (defined (my $path_ref = $self->path_ref($controller, $actions))) {
        $path{'$ref'} = $self->path_ref($controller, $actions);
    }

    if (defined (my $servers = $self->servers($controller, $actions))) {
        $path{'servers'} = $servers;
    }

    if (defined (my $parameters = $self->parameters($controller, $actions))) {
        $path{'parameters'} = $parameters;
    }

    return \%path;
}


=head2 generateSchemas

generate for Schemas

=cut

sub generateSchemas {
    my ($self) = @_;
    return undef;
}

=head2 path_ref

ref for path

=cut

sub path_ref {
    undef;
}

=head2 servers

servers for path

=cut

sub servers {
    my ($self) = @_;
    return ;
}

=head2 parameters

parameters for path

=cut

sub parameters {
    my ($self) = @_;
    return ;
}

=head2 $self->summary($controller, @actions)

Generate the summary of the path

  my $summary = $self->summary($controller, @actions)

=cut

sub summary {
    my ($self, $c, @a) = @_;
    my $class = ref $c || $c;
    my $pod = $self->extract_text_from_pod($class, [qw(SUMMARY)]);
    if (!defined $pod) {
        return undef;
    }

    return $self->pod_to_markdown($pod);
}

=head2 description

description from controller for path

=cut

sub description {
    my ($self, $c, @a) = @_;
    my $class = ref $c || $c;
    my $pod = $self->extract_text_from_pod($class, [qw(DESCRIPTION)]);
    if (!defined $pod) {
        return undef;
    }

    my $text =  $self->pod_to_text($pod);
    if (!defined $text) {
        return undef;
    }

    $text =~ s/DESCRIPTION\n//;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}

=head2 extract_text_from_pod

extract text from pod

=cut

sub extract_text_from_pod {
    my ($self, $class, $sections) = @_;
    my $file = pod_where( { -inc => 1 }, $class); 

    if (!defined $file) {
        return undef;
    }

    my $pod;
    open(my $fh, ">", \$pod);
    podselect({-output => $fh, sections => $sections }, $file);
    if (!$pod) {
       return undef; 
    }

    return $pod;
}

=head2 pod_to_markdown

pod to markdown

=cut

sub pod_to_markdown {
    my ($self, $pod) = @_;
    return $self->pod_to_something($pod, "Pod::Markdown");
}

=head2 pod_to_text

pod to text

=cut

sub pod_to_text {
    my ($self, $pod) = @_;
    return $self->pod_to_something($pod, "Pod::Text");
}

=head2 pod_to_something

pod to some class

=cut

sub pod_to_something {
    my ($self, $pod, $class) = @_;
    my $out;
    my $parser = $class->new;
    $parser->output_string(\$out);
    $parser->parse_string_document($pod);
    return $out;
}

=head2 operations

operations for a path

=cut

sub operations {
    my ($self, $c, $actions) = @_;
    my %ops;
    for my $action (@{$actions // []}) {
        for my $m (@{$action->{methods}}) {
            $m = lc($m);
            my $op = $self->operation($c, $m, $action);
            next if !defined $op;
            $ops{$m} = $op;
        }
    }

    return %ops;
}

=head2 operation

operation

=cut

sub operation {
    my ( $self, $c, $m, $action ) = @_;
    my $responses = $self->operation_generation('responses', $c, $m, $action);
    if (!defined $responses) {
        return undef;
    }

    my %op = (
        responses => $responses
    );
    for my $scope (qw(tags summary description externalDocs operationId parameters requestBody callbacks deprecated security servers)) {
        if (defined(my $value = $self->operation_generation($scope, $c, $m, $action))) {
            $op{$scope} = $value;
        }
    }

    return \%op;
}

=head2 operation_generators

the lookup for operation generators

=cut

sub operation_generators {
    return {};
}

=head2 operation_generation

Calls to the generators for operation parameters

=cut

sub operation_generation {
    my ( $self, $scope, $c, $m, $action ) = @_;
    my $generators = $self->operation_generators;
    if (!exists $generators->{$scope}) {
        return undef;
    }
    my $a = $action->{action};
    if (!exists $generators->{$scope}{$a}) {
        return undef;
    }

    my $method = $generators->{$scope}{$a};
    return $self->$method($scope, $c, $m, $action);
}

=head2 performLookup

perform Lookup for generations

=cut

sub performLookup {
    my ($self, $lookup, $key, $default) = @_;

    if (!defined $key || !defined $lookup) {
        return $default;
    }

    if (!exists $lookup->{$key}) {
        return $default;
    }

    return $lookup->{$key};
}

=head2 operationDescriptionsLookup

operation Descriptions Lookup

=cut

sub operationDescriptionsLookup {
    undef
}

=head2 operationParametersLookup

operation Parameters Lookup

=cut

sub operationParametersLookup {
    undef
}

=head2 operationParameters

operation Parameters

=cut

sub operationParameters {
    my ($self, $scope, $c, $m, $a) = @_;
    return $self->performLookup($self->operationParametersLookup, $a->{action}, []);
}

=head2 operationDescription

operationDescription

=cut

sub operationDescription {
    my ($self, $scope, $c, $m, $a) = @_;
    return $self->performLookup($self->operationDescriptionsLookup, $a->{action}, undef);
}

=head2 operationId

operation Id

=cut

sub operationId {
    my ($self, $scope, $c, $m, $a) = @_;
    return $a->{operationId};
}

=head2 schemaItemPath

schema Item Path

=cut

sub schemaItemPath {
    my ($self, $controller) = @_;
    my $class = ref ($controller) || $controller;
    $class =~ s/pf::UnifiedApi::Controller:://;
    my @paths = split('::', $class);
    my $name = pop @paths;
    my $noun = noun($name);
    my $singular = $noun->singular;
    my $prefix = "/components/schemas";
    return join('/', $prefix, join("", @paths, $singular));
}

=head2 schemaListPath

schema List Path

=cut

sub schemaListPath {
    my ($self, $controller) = @_;
    my $class = ref ($controller) || $controller;
    $class =~ s/pf::UnifiedApi::Controller:://;
    my @paths = split('::', $class);
    my $name = pop @paths;
    my $prefix = "/components/schemas";
    return join('/', $prefix, join("", @paths, "${name}List"));
}

sub path_parameter {
    my ($self, $name, $description) = @_;
    return {
        in     => 'path',
        schema => { type => 'string' },
        name   => $name,
        (defined $description ? (description => $description) : ()),
    };
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

1;
