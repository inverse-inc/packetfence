package pfappserver::Form::Config::Pfmon::certificates_check;

=head1 NAME

pfappserver::Form::Config::Pfmon::certificates_check

=head1 DESCRIPTION

Web form for certificates_check pfmon task

=cut

use HTML::FormHandler::Moose;

use pfappserver::Form::Config::Pfmon qw(default_field_method);

extends 'pfappserver::Form::Config::Pfmon';
with 'pfappserver::Base::Form::Role::Help';


has_field 'delay' => (
    type            => 'Duration',
    default_method  => \&default_field_method,
    tags => { 
        after_element   => \&help,
        help            => "Minimum gap before certificate expiration date (will the certificate expires in ...)",
    },
);

has_field 'certificates' => (
    type            => 'TextArea',
    default_method  => \&default_field_method,
    tags => { 
        after_element   => \&help,
        help            => "SSL certificate(s) to monitor. Comma-delimited list",
    },
);

has_block definition => (
    render_list => [qw(type status interval delay certificates)],
);


=head2 default_type

default value of type

=cut

sub default_type {
    return "certificates_check";
}


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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
