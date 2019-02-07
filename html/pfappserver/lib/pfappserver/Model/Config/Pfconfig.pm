package pfappserver::Model::Config::Pfconfig;
=head1 NAME

pfappserver::Model::Config::Pfconfig

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Pf to interface with pfconfig's configuration
This doesn't use the ConfigStore

=cut

use Moose;
use namespace::autoclean;
use pfconfig::config;
use pfconfig::constants;
use Config::IniFiles;

extends 'pfappserver::Base::Model';

=head1 FIELDS

=head2 config_file

pfconfig's config file

=cut

has config_file => (
   is => 'ro',
   lazy => 1,
   isa => 'Config::IniFiles',
   builder => '_build_config_file'
);

=head2 _build_config_file

=cut

sub _build_config_file {
    my $file = $pfconfig::constants::CONFIG_FILE_PATH;
    my $config = Config::IniFiles->new( -file => $file );
    return $config;
}

=head2 remove

Delete an existing item

=cut

sub remove {
    my ($self,$id) = @_;
    return ($STATUS::INTERNAL_SERVER_ERROR, "Cannot delete this item");
}

sub update_mysql_credentials {
    my ($self, $user, $password) = @_;
    $self->config_file->setval('mysql', 'user', $user);
    $self->config_file->setval('mysql', 'pass', $password);
    return ($self->config_file->RewriteConfig(), undef);
}

sub update_db_name {
    my ($self, $db) = @_;
    $self->config_file->setval('mysql', 'db', $db);
    return ($self->config_file->RewriteConfig(), undef);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};


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

