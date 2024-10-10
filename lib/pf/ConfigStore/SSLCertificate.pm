package pf::ConfigStore::SSLCertificate;

=head1 NAME

pf::ConfigStore::SSLCertificate
Store SSLCertificate Rules

=cut

=head1 DESCRIPTION

pf::ConfigStore::SSLCertificate

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($ssl_config_file $ssl_default_config_file);
extends 'pf::ConfigStore';

sub configFile { $ssl_config_file };

sub importConfigFile { $ssl_default_config_file }

sub pfconfigNamespace {'config::Ssl'}

=head2 cleanupAfterRead

Clean up realm data

=cut

sub cleanupAfterRead {
    my ($self, $id, $item) = @_;
    $self->join_line($item, $self->_fields_expanded);
}

sub join_line {
    my ($self, $item, @fields) = @_;
    for my $f (@fields) {
        if (exists $item->{$f}) {
            my $val = $item->{$f};
            if (ref($val) eq 'ARRAY') {
                $item->{$f} = join("\n", @$val);
            }
        }
    }
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(cert key ca intermediate);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
