package pfconfig::namespaces::FilterEngine::AccessScopes;

=head1 NAME

pfconfig::namespaces::FilterEngine::AccessScopes - Base class for scoped filter engine

=cut

=head1 DESCRIPTION

pfconfig::namespaces::FilterEngine::AccessScopes

=cut

use strict;
use warnings;
use pfconfig::namespaces::config;
use pf::config::builder::scoped_filter_engines;
use pf::log;
use pf::IniFiles;

use base 'pfconfig::namespaces::resource';

=head2 parentConfig

Parent pfconfig::namespaces::config object

=cut

sub parentConfig {
    my ($self) = @_;
    my $class = ref($self) || $self;
    die "${class}::parentConfig has not been implemented\n";
}


=head2 build

Build the scoped filter engines

=cut

sub build {
    my ($self)            = @_;
    my $config   = $self->parentConfig;
    $config->init;
    my $file = $config->{file};
    my $ini = pf::IniFiles->new(%{$config->{added_params}}, -file => $file, -allowempty => 1);
    unless ($ini) {
        my $error_msg = join("\n", @pf::IniFiles::errors, "");
        get_logger->error($error_msg);
        warn($error_msg);
        return {};
    }

    my $builder = pf::config::builder::scoped_filter_engines->new;
    my ($errors, $accessScopes) = $builder->build($ini);
    for my $err (@{ $errors // [] }) {
        my $error_msg =  "$file: $err->{rule}) $err->{message}";
        get_logger->error($error_msg);
        warn($error_msg);
    }

    $self->{errors} = $errors;
    return $accessScopes;
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
