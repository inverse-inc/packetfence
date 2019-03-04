package pfappserver::Form::Config::Source::Mirapay;

=head1 NAME

pfappserver::Form::Source::Mirapay

=cut

=head1 DESCRIPTION

Form definition to create or update an Mirapay authentication source.

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
use pf::config qw($fqdn);
extends 'pfappserver::Form::Config::Source::Billing';
with 'pfappserver::Base::Form::Role::Help';
with 'pfappserver::Base::Form::Role::SourceLocalAccount';

has_field base_url => (
    type => 'Select',
    label => 'Iframe Base url',
    options => [
        { label => 'Staging', value => "https://staging.eigendev.com/MiraSecure/GetToken.php" },
        { label => 'Prod 1',  value => "https://ms1.eigendev.com/MiraSecure/GetToken.php" },
        { label => 'Prod 2',  value => "https://ms2.eigendev.com/MiraSecure/GetToken.php" },
    ],
    default => "https://staging.eigendev.com/MiraSecure/GetToken.php",
    required => 1,
);

has_field direct_base_url => (
    type => 'Text',
    label => 'Direct Base url',
    default => "https://staging.eigendev.com/OFT/EigenOFT_d.php",
    required => 1,
    element_class => ['input-xxlarge'],
);

has_field terminal_id => (
    type => 'Text',
    label => 'Terminal ID',
    required => 1,
    tags => {
        after_element => \&help,
        help => 'Terminal ID for Mirapay Direct',
    },
    # Default value needed for creating dummy source
    default => '',
);

has_field terminal_group_id => (
    type => 'Text',
    label => 'Terminal Group ID',
    tags => {
        after_element => \&help,
        help => 'Terminal Group ID for Mirapay Direct',
    },
);

has_field shared_secret_direct => (
    type => 'Text',
    label => 'Shared Secret Direct',
    required => 1,
    tags => {
        after_element => \&help,
        help => 'MKEY for Mirapay Direct',
    },
    element_class => ['input-xlarge'],
    # Default value needed for creating dummy source
    default => '',
);

has_field shared_secret => (
    type => 'Text',
    label => 'Shared Secret',
    required => 1,
    tags => {
        after_element => \&help,
        help => 'MKEY for the iframe',
    },
    element_class => ['input-xlarge'],
    # Default value needed for creating dummy source
    default => '',
);

has_field service_fqdn => (
    label => 'Service FQDN',
    type => 'Text',
    default_method => sub { $fqdn },
    tags => {
        after_element => \&help,
        help => 'Service FQDN',
    },
);

has_field merchant_id => (
    label => 'Merchant ID',
    type => 'Text',
    required => 1,
    # Default value needed for creating dummy source
    default => '',
);

has_block definition => (
    render_list => [qw(
        service_fqdn
        currency
        test_mode
        send_email_confirmation
    )]
);

has_block iframe => (
    render_list => [qw(
        base_url
        merchant_id
        shared_secret
    )]
);

has_block direct => (
    render_list => [qw(
        direct_base_url
        terminal_id
        shared_secret_direct
        terminal_group_id
    )]
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
