package pfappserver::Form::Field::Country;
=head1 NAME

pfappserver::Form::Field::Country add documentation

=cut

=head1 DESCRIPTION

pfappserver::Form::Field::Country

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Select';
use Locale::Country;
use namespace::autoclean;

our @COUNTRIES = Locale::Country::all_country_names();

our @DEFAULT_OPTIONS = map { { label => $_, value => uc(country2code($_)) } } sort @COUNTRIES;


sub build_options {
    return \@DEFAULT_OPTIONS;
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

