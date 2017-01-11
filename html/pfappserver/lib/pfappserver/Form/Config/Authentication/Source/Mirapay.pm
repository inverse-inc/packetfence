package pfappserver::Form::Config::Authentication::Source::Mirapay;

=head1 NAME

pfappserver::Form::Authentication::Source::Mirapay

=cut

=head1 DESCRIPTION

pfappserver::Form::Authentication::Source::Mirapay

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Authentication::Source::Billing';

has_field base_url => (
    type => 'Text',
    default => "https://staging.eigendev.com/MiraSecure/GetToken.php",
    required => 1,
);

has_field shared_secret => (
    type => 'Text',
    required => 1,
);

has_field merchant_id => (
    type => 'Text',
    required => 1,
);

has_block definition => (
    render_list => [qw(base_url shared_secret merchant_id currency test_mode create_local_account local_account_logins)]
);


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
