package pfconfig::namespaces::config::Pfdetect;

=head1 NAME

pfconfig::namespaces::config::Pfdetect

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Pfdetect

This module creates the configuration hash associated to pfdetect.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($pfdetect_config_file);
use pf::util;
use Sort::Naturally qw(nsort);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $pfdetect_config_file;
    $self->{config} = $self->{cache}->get_cache('config::Pf');
}

sub build_child {
    my ($self) = @_;
    my %tmp_cfg = %{ $self->{cfg} };
    # There for backward compatibility for when suricata or snort is configured directly in PacketFence
    # Should this feature go, the code below can be removed
    # This will start a pfdetect process if the detection engine is enabled in PacketFence
    #
    my @parser_ids = grep { /^\S+$/  } keys %tmp_cfg;
    my %config_data;
    for my $id (@parser_ids) {
        my $entry = $tmp_cfg{$id};
        $config_data{$id} = $entry;
        if ($entry->{type} eq 'regex') {
            my @rules; 
            my @rule_ids = grep { /^$id rule/  } keys %tmp_cfg;
            for my $rule_id (@rule_ids) {
                $rule_id =~ /^$id rule (.*)/;
                my $rule = {%{$tmp_cfg{$rule_id}}, name => $1};
                my $regex = eval {qr/$rule->{regex}/};
                if ($@) {
                    print STDERR "Invalid regex '$rule->{regex}'\n";
                    next;
                }
                $rule->{regex}  = $regex;
                my @action_keys = nsort grep { /^action\d+$/ } keys %$rule;
                $rule->{actions} = [delete @$rule{@action_keys}];
                push @rules, $rule;
            }
            $entry->{rules} = \@rules;
        }
    }

    return \%config_data;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

