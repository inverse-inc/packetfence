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

=head2 generate_path

generate_path

=cut

sub generate_path {
    my ($self, $controller, $actions) = @_;
    my %path;
    if (defined (my $summary = $self->summary($controller, $actions))) {
        $path{summary} = $summary
    }

    if (defined (my $description = $self->description($controller, $actions))) {
        $path{description} = $description
    }

    if (defined (my $path_ref = $self->path_ref($controller, $actions))) {
        $path{'$ref'} = $self->path_ref($controller, $actions);
    }

    my %ops = $self->operations($controller, $actions);
    if (keys %ops) {
        %path = (%path, %ops);
    }

    if (defined (my $servers = $self->servers($controller, $actions))) {
        $path{'servers'} = $servers;
    }

    if (defined (my $parameters = $self->parameters($controller, $actions))) {
        $path{'parameters'} = $parameters;
    }

    return \%path;
}


=head2 generate_schemas

generate_schemas

=cut

sub generate_schemas {
    my ($self) = @_;
    return undef;
}

=head2 setup

setup

=cut

sub setup {
    my ($self, $c, $actions) = @_;
    return;
}

=head2 path_ref

path_ref

=cut

sub path_ref {
    undef;
}

=head2 servers

servers

=cut

sub servers {
    my ($self) = @_;
    return ;
}

=head2 parameters

parameters

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

description

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

sub summary_classes {
    my ($self, $c) = @_;
    return (ref $c || $c);
}

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

sub pod_to_markdown {
    my ($self, $pod) = @_;
    return $self->pod_to_something($pod, "Pod::Markdown");
}

sub pod_to_text {
    my ($self, $pod) = @_;
    return $self->pod_to_something($pod, "Pod::Text");
}

sub pod_to_something {
    my ($self, $pod, $class) = @_;
    my $out;
    my $parser = $class->new;
    $parser->output_string(\$out);
    $parser->parse_string_document($pod);
    return $out;
}

sub operations {
    my ($self, $c, $actions) = @_;
    my %ops;
    for my $action (@{$actions // []}) {
        for my $m (@{$action->{methods}}) {
            $m = lc($m);
            my $op = $self->operation($c, $m, $action);
            next if !defined $op;
            $ops{$m} = $self->operation($c, $m, $action);
        }
    }

    return %ops;
}

=head2 operation

operation

=cut

sub operation {
    my ( $self, $c, $m, $action ) = @_;
    my %op;
    for my $scope (qw(tags summary description externalDocs operationId parameters requestBody responses callbacks deprecated security servers)) {
        if (defined(my $value = $self->operation_generation($scope, $c, $m, $action))) {
            $op{$scope} = $value;
        }
    }

    return keys %op == 0 ? undef : \%op;
}

sub operation_generators {
    return {};
}

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

sub operationDescriptionsLookup {
    undef
}

sub operationParametersLookup {
    undef
}

sub operationParameters {
    my ($self, $scope, $c, $m, $a) = @_;
    return $self->performLookup($self->operationParametersLookup, $a->{action}, []);
}

sub operationDescription {
    my ($self, $scope, $c, $m, $a) = @_;
    return $self->performLookup($self->operationDescriptionsLookup, $a->{action}, undef);
}

sub operationId {
    my ($self, $scope, $c, $m, $a) = @_;
    return $a->{operationId};
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
