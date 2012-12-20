package pfappserver::Model::Config::Switches;

=head1 NAME

pfappserver::Model::Config::Switches - Catalyst Model

=head1 DESCRIPTION

Configuration module for operations involving conf/switches.conf.

=cut

use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use Readonly;

use pf::config;
use pf::config::ui;
use pf::error qw(is_error is_success);

extends 'pfappserver::Model::Config::IniStyleBackend';

Readonly::Scalar our $NAME => 'Switches';

sub _getName        { return $NAME };
sub _myConfigFile   { return $pf::config::switches_config_file };


=head1 METHODS

=over

=item create

=cut
sub create {
    my ( $self, $switch, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    my $switches_conf = $self->load_config;
    my $tied_conf = tied(%$switches_conf);

    $self->update_config(%$switches_conf);
}

=item delete

=cut
sub delete {
    my ( $self, $switch ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
}


=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

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
