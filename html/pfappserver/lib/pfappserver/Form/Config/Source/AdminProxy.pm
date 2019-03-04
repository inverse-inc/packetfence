package pfappserver::Form::Config::Source::AdminProxy;

=head1 NAME

pfappserver::Form::Config::Source::AdminProxy - Form for the AdminProxySource

=cut

=head1 DESCRIPTION

Form definition to create or update an AdminProxy authentication source.

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
use pf::util qw(valid_ip);
extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help';

has_block definition => (
    render_list => [qw(proxy_addresses user_header group_header)],
);

has_field 'proxy_addresses' => (
    type => 'TextArea',
    required => 1,
    # Default value needed for creating dummy source
    default => '',
    tags => {
        after_element => \&help,
        help => 'A comma seperated list of IP Address',
    }
);

has_field 'user_header' => (
    type => 'Text',
    required => 1,
    # Default value needed for creating dummy source
    default => '',
);

has_field 'group_header' => (
    type => 'Text',
    required => 1,
    # Default value needed for creating dummy source
    default => '',
);

=head2 validate

Validate Proxy IP Addresses

=cut

sub validate {
    my ($self) = @_;
    my $proxy_addresses_field = $self->field('proxy_addresses');
    my $proxy_addresses = $proxy_addresses_field->value;
    for my $ip (split(/\s*,\s*/, $proxy_addresses)) {
        unless (valid_ip($ip)) {
            $proxy_addresses_field->add_error("$ip is invalid");
        }
    }
    return;
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
