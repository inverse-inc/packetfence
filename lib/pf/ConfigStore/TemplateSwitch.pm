package pf::ConfigStore::TemplateSwitch;

=head1 NAME

pf::ConfigStore::TemplateSwitch add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::TemplateSwitch

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moo;
use namespace::autoclean;
use pf::util qw(listify);
use pf::constants::template_switch qw(@RADIUS_ATTRIBUTE_SETS);
use pf::file_paths qw($template_switches_config_file $template_switches_default_config_file);
extends 'pf::ConfigStore';

sub configFile { $template_switches_config_file }

sub importConfigFile { $template_switches_default_config_file }

sub pfconfigNamespace {'config::TemplateSwitches'}

sub cleanupAfterRead {
    my ($self, $id, $item) = @_;
    for my $f (@RADIUS_ATTRIBUTE_SETS) {
        if (exists $item->{$f}) {
            my $value = $item->{$f};
            if ($value eq "") {
                $item->{$f} = [];
            } else {
                $item->{$f} = listify($value);
            }
        }
    }
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
