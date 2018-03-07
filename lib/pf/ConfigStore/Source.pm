package pf::ConfigStore::Source;

=head1 NAME

pf::ConfigStore::Source

=cut

=head1 DESCRIPTION

pf::ConfigStore::Source

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moo;
use namespace::autoclean;
use pf::file_paths qw($authentication_config_file);
use Sort::Naturally qw(nsort);
extends 'pf::ConfigStore';
with 'pf::ConfigStore::Role::ReverseLookup';

use pf::file_paths qw($authentication_config_file);

sub configFile {$authentication_config_file};

sub pfconfigNamespace { 'config::Authentication' }

=head2 canDelete

canDelete

=cut

sub canDelete {
    my ($self, $id) = @_;
    return !$self->isInProfile('sources', $id) && $self->SUPER::canDelete($id);
}

=head2 _Sections

=cut

sub _Sections {
    my ($self) = @_;
    return grep { /^\S+$/ }  $self->SUPER::_Sections();
}

=head2 _update_section

Update section

=cut

sub _update_section {
    my ($self, $section, $assignments) = @_;
    my $admin_rules = delete $assignments->{"${Rules::ADMIN}_rules"} // [];
    my $auth_rules = delete $assignments->{"${Rules::AUTH}_rules"} // [];
    $_->{class} = $Rules::ADMIN for @$admin_rules;
    $_->{class} = $Rules::AUTH for @$auth_rules;
    my @rules = (@$admin_rules, @$auth_rules);
    $self->SUPER::_update_section($section, $assignments);
    my $cachedConfig = $self->cachedConfig;
    for my $sub_section ( grep {/^$section rule/} $cachedConfig->Sections ) {
        $cachedConfig->DeleteSection($sub_section);
    }
    for my $rule (@rules) {
        my $name = delete $rule->{id};
        $self->_update_array_field($rule, "actions", "action");
        $self->_update_array_field($rule, "conditions", "condition");
        $self->SUPER::_update_section("$section rule $name", $rule);
    }
}

=head2 _update_array_field

Update array field data to seperate field for each entry

=cut

sub _update_array_field {
    my ($self, $data, $from, $to) = @_;
    my $fields = delete $data->{$from} // [];
    my $i = 0;
    for my $field (@$fields) {
        $data->{"${to}$i"} = $field;
        $i++;
    }
}

sub cleanupAfterRead {
    my ($self, $id, $item, $idKey) = @_;
    $item->{"${Rules::AUTH}_rules"} = [];
    $item->{"${Rules::ADMIN}_rules"} = [];
    for my $sub_section ( $self->cachedConfig->Sections ) {
        next unless  $sub_section =~ /^$id rule (.*)$/;
        my $id = $1;
        my $rule = $self->readRaw($sub_section);
        my $class = delete $rule->{class} // $Rules::AUTH;
        $rule->{id} = $id;
        my @action_keys = nsort grep {/^action\d+$/} keys %$rule;
        $rule->{actions} = [delete @$rule{@action_keys}];
        my @conditions_keys = nsort grep {/^condition\d+$/} keys %$rule;
        $rule->{conditions} = [delete @$rule{@conditions_keys}];
        push @{$item->{"${class}_rules"}}, $rule;
    }
    if ($item->{type} eq 'SMS') {
        $self->expand_list($item, 'sms_carriers');
    }
    $self->expand_list($item, qw(realms));
}

sub cleanupBeforeCommit {
    my ($self, $id, $item) = @_;
    if ($item->{type} eq 'SMS') {
        $self->flatten_list($item, 'sms_carriers');
    }
    if ($item->{type} eq 'Eduroam') {
        $self->flatten_list($item, qw(local_realm reject_realm));
    }
    $self->flatten_list($item, qw(realms));
}

before rewriteConfig => sub {
    my ($self) = @_;
    my $config = $self->cachedConfig;
    $config->ReorderByGroup();
};


__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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
