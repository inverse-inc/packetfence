package pf::mfa;
=head1 NAME

pf::mfa add documentation

=cut

=head1 DESCRIPTION

pf::mfa

=cut

use strict;
use warnings;
use Moo;
use pf::log;
use pf::constants;

has id => (is => 'rw', required => 1);

has description => (is => 'rw', default => "MFA");

=head2 chache_duration

Number of time to keep information in the cache

=cut

has cache_duration => (is => 'rw' );

=head2 template

The template to use for provisioning

=cut

has template => (is => 'rw', lazy => 1, builder => 1 );

=head1 METHODS

=head2 _build_template

Creates a template from the name of the class

=cut

sub _build_template {
    my ($self) = @_;
    my $type = ref($self) || $self;
    $type =~ s/^pf:://;
    $type =~ s/::/\//g;
    return "${type}.html";
}

=head2 module_description

Returns the module description

Parent returns empty so that the factory use the own child module name if not defined in child module

=cut

sub module_description { '' }

sub redirect_info { {} }
sub verify_response { 0 }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
