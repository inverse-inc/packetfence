package pf::config::builder::pfdetect;

=head1 NAME

pf::config::builder::pfdetect - Build the config for pfdetect from pfdetect.conf

=head1 DESCRIPTION

Build the config for pfdetect from pfdetect.conf

=cut

use strict;
use warnings;
use pf::util qw(strip_filename_from_exceptions normalize_time);
use Sort::Naturally qw(nsort);
use pf::log;
use base qw(pf::config::builder);
use pf::constants::pfdetect;

=head2 buildEntry

buildEntry

=cut

sub buildEntry {
    my ($self, $buildData, $id, $entry) = @_;
    $entry->{rate_limit} = normalize_time($entry->{rate_limit} // $pf::constants::pfdetect::RATE_LIMIT_DEFAULT);
    if ($entry->{type} eq 'regex') {
        my @rules;
        my @rule_ids = grep { /^$id rule/ } @{$buildData->{ini_sections}};
        for my $rule_id (@rule_ids) {
            $rule_id =~ /^$id rule (.*)/;
            my $rule = {%{$self->getSectionData($buildData->{ini}, $rule_id)}, name => $1};
            eval {
                use re::engine::RE2 -strict => 1;
                qr/$rule->{regex}/
            };
            if ($@) {
                $self->_error(
                    $buildData, $rule_id,
                    "Regex /$rule->{regex}/ is not in RE2 syntax",
                    strip_filename_from_exceptions($@)
                );
                next;
            }
            $rule->{rate_limit} = normalize_time($rule->{rate_limit} // $pf::constants::pfdetect::RATE_LIMIT_DEFAULT) . "";
            my @action_keys = nsort grep { /^action\d+$/ } keys %$rule;
            $rule->{actions} = [delete @$rule{@action_keys}];
            push @rules, $rule;
        }

        $entry->{rules} = \@rules;
    }

    return $entry;
}

=head2 _error

Records any error that occurs while building the config

=cut

sub _error {
    my ($self, $build_data, $rule, $msg, $add_info) = @_;
    my $long_msg = $msg. (defined($add_info) ? " : $add_info" : '');
    $long_msg .= "\n" unless $long_msg =~ /\n\z/s;
    push @{$build_data->{errors}}, {rule => $rule, message => $long_msg};
}

=head2 skipEntry

skipEntry

=cut

sub skipEntry {
    my ($self, $buildData, $id, $entry) = @_;
    return $id !~ /^\S+$/;
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
