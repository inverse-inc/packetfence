package pfappserver::Model::Authentication::Source;

=head1 NAME

pfappserver::Model::Authentication::Source - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;
use Readonly;

use pf::authentication;
use pf::error qw(is_error is_success);

=head2

=cut

sub update {
    my ($self, $source_id, $source_obj, $def_ref) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    unless ($source_id) {
        # Add a new source
        my $type = $source_obj->{type};
        $source_obj = newAuthenticationSource($type, $def_ref->{id}, $def_ref);
        unless ($source_obj) {
            $logger->error("Authentication source of type $type is not supported.");
        }
        push(@authentication_sources, $source_obj);
    }

    # Update attributes
    foreach my $attr ($source_obj->meta->get_all_attributes()) {
        $attr = $attr->name;
        # Some attributes don't have to be written to disk
        unless (grep { $_ eq $attr } qw[rules type unique class]) {
            $source_obj->$attr($def_ref->{$attr});
        }
    }

    # Update rules order
    my %valid_rules = map { $_->{id} => $_ } @{$source_obj->{rules}};
    my @sorted_rules;
    foreach my $rule (@{$def_ref->{rules}}) {
        if ($valid_rules{$rule->{id}}) {
            push(@sorted_rules, $valid_rules{$rule->{id}});
        }
    }
    $source_obj->{rules} = \@sorted_rules;

    # Write configuration file to disk
    writeAuthenticationConfigFile();

    return ($STATUS::OK, "The authentication source was successfully saved.");
}

=head2

=cut

sub delete {
    my ($self, $source_obj) = @_;

    deleteAuthenticationSource($source_obj->id);
    writeAuthenticationConfigFile();

    return ($STATUS::OK, "The user source was successfully deleted.");
}

=head2

=cut

sub updateRule {
    my ($self, $source_id, $rule_id, $def_ref) = @_;

    my $source = getAuthenticationSource($source_id);
    if ($source) {
        my $rule;
        if ($rule_id) {
            # Update an existing rule
            for (my $i = 0; $i < scalar @{$source->rules}; $i++) {
                if ($source->rules->[$i]->id eq $rule_id) {
                    $rule = $source->rules->[$i];
                }
            }
        }
        unless ($rule) {
            # Add a new rule
            $rule = pf::Authentication::Rule->new(id => $def_ref->{id});
            $source->add_rule($rule);
        }
        # Update attributes
        foreach my $attr ($rule->meta->get_attribute_list()) {
            $rule->$attr($def_ref->{$attr} || '');
        }
        # Write configuration file to disk
        writeAuthenticationConfigFile();
        return ($STATUS::OK, "The rule was successfully updated.");;
    }
    else {
        return ($STATUS::NOT_FOUND, "The user source does not exist.");
    }
}

=back

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
