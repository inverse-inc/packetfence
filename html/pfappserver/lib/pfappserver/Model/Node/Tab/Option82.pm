package pfappserver::Model::Node::Tab::Option82;

=head1 NAME

pfappserver::Model::Node::Tab::Option82 -

=cut

=head1 DESCRIPTION

pfappserver::Model::Node::Tab::Option82

=cut

use strict;
use warnings;
use pf::dhcp_option82;
use pf::SwitchFactory;

=head2 process_view

Process view

=cut

sub process_view {
    my ($self, $c, @args) = @_;
    my $mac = $c->stash->{mac};
    my ($option_82) = dhcp_option82_view($mac);
    return ($STATUS::OK, {
        item => $option_82,
        columns => [sort @pf::dhcp_option82::FIELDS],
        display_columns => [sort keys %pf::dhcp_option82::HEADINGS],
        headings => \%pf::dhcp_option82::HEADINGS,
        switch_config => \%pf::SwitchFactory::SwitchConfig,
    });
}

=head2 process_tab

Process tab

=cut

sub process_tab {
    my ($self, $c, @args) = @_;
    return ($STATUS::OK, {});
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
