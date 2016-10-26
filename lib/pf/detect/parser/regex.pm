package pf::detect::parser::regex;

=head1 NAME

pf::detect::parser::regex -

=cut

=head1 DESCRIPTION

pf::detect::parser::regex

=cut

use strict;
use warnings;
use pf::log;
use pf::api::queue;
use Moo;
extends qw(pf::detect::parser);

has rules => (is => 'rw', default => sub { [] });

sub parse {
    my ($self, $line) = @_;
    foreach my $rule (@{$self->rules}) {
        next unless $line =~ $rule->{regex};
        my %data = %+;
        foreach my $action (@{$rule->{actions}}) { 
            $self->doAction($rule, \%data, $action);
        }
        return 0 unless $rule->{send_add_event};
        $data{events} = { %{$rule->{events}}};
        return \%data;
    }
    return undef;
}

sub doAction {
    my ($self, $rule, $data, $action_spec) = @_;
    my $logger = get_logger;
    unless ($action_spec =~ /^\s*([^:]+)\s*:\s*(.*)\s*$/) {
        $logger->error("Invalid action spec provided");
        return;
    }
    my $action = $1;
    my $action_params = $2;
    my $params = $self->evalParams($action_params, $data);
    my $apiclient = $self->getApiClient;
    $apiclient->notify($action, @$params);
}

sub getApiClient {
    my ($self) = @_;
    return pf::api::jsonrpcclient->new();
}

sub evalParams {
    my ($self, $action_params, $args) = @_;
    my @params = split(/\s*,\s*/, $action_params);
    my @return;
    foreach my $param (@params) {
        $param =~ s/\$([A-Za-z0-9_]+)/$args->{$1} \/\/ '' /ge;
        my @param_unit = split(/\s*=\s*/, $param);
        push @return, @param_unit;
    }
    return \@return;
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

