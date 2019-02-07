package pf::ConfigStore::Pfdetect;
=head1 NAME

pf::ConfigStore::Pfdetect
Store Pfdetect configuration

=cut

=head1 DESCRIPTION

pf::ConfigStore::Pfdetect

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($pfdetect_config_file);
use Sort::Naturally qw(nsort);
extends 'pf::ConfigStore';

sub configFile { $pfdetect_config_file };

sub pfconfigNamespace {'config::Pfdetect'}


=head2 _update_section

Override _update_section to normalize actions in rule for the regex parser

=cut

sub _update_section {
    my ($self, $section, $assignments) = @_;
    my $rules = delete $assignments->{rules} // [];
    $self->SUPER::_update_section($section, $assignments);
    my $cachedConfig = $self->cachedConfig;
    for my $sub_section ( grep {/^$section rule/} $cachedConfig->Sections ) {
        $cachedConfig->DeleteSection($sub_section);
    }
    for my $rule (@$rules) {
        my $name = delete $rule->{name};
        my $actions = delete $rule->{actions} // [];
        my $i = 0;
        for my $action (@$actions) {
            $rule->{"action$i"} = $action;
            $i++;
        }
        $self->SUPER::_update_section("$section rule $name", $rule);
    }
}

=head2 cleanupBeforeCommit

cleanupBeforeCommit

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $data) = @_;
    if ($data->{type} eq 'regex') {
        delete $data->{loglines};
    }
    return ;
}

=head2 _Sections

Just get the top level sections

=cut

sub _Sections {
    my ($self) = @_;
    return grep { /^\S+$/ }  $self->SUPER::_Sections();
}

=head2 cleanupAfterRead

Expand the rules for a regex parser

=cut

sub cleanupAfterRead {
    my ($self, $id, $item, $idKey) = @_;
    if ($item->{type} eq 'regex' ) {
        my @rules;
        for my $sub_section ( $self->cachedConfig->Sections ) {
            next unless  $sub_section =~ /^$id rule (.*)$/;
            my $id = $1;
            my $rule = $self->readRaw($sub_section);
            $rule->{name} = $id;
            my @action_keys = nsort grep {/^action\d+$/} keys %$rule;
            $rule->{actions} = [delete @$rule{@action_keys}];
            push @rules, $rule;
        }
        $item->{rules} = \@rules;
    }
}


__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

