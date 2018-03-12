package pfappserver::Form::Config::Fingerbank::Onboard;

=head1 NAME

pfappserver::Form::Config::Fingerbank::Onboard

=head1 DESCRIPTION

Form definition for Fingerbank onboarding procedure

=cut

use HTML::FormHandler::Moose;
use pf::log;
use fingerbank::API;
use pf::error qw(is_error);

extends 'pfappserver::Base::Form';

has_field 'api_key' => (
    type     => 'Text',
    label    => 'API Key',
    required => 1,
);

sub validate_api_key {
    my ($self, $field) = @_;
    get_logger->info("Validating API key: " . $field->value);

    my ($status, $msg) = fingerbank::API->new_from_config->test_key($field->value);
    if(is_error($status)) {
        $field->add_error($msg);
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
