package fingerbank::Query;

use Moose;
use namespace::autoclean;

use JSON;
use Module::Load;
use POSIX;

use fingerbank::Config;
use fingerbank::Constant qw($TRUE $LOCAL_SCHEMA);
use fingerbank::Log;
use fingerbank::Model::Combination;
use fingerbank::Model::Device;
use fingerbank::Model::Endpoint;
use fingerbank::Util qw(is_enabled is_disabled is_error is_success);
use fingerbank::SourceMatcher;
use fingerbank::Source::LocalDB;
use fingerbank::Source::Collector;
use fingerbank::NullCache;

has 'cache' => (is => 'rw', default => sub { fingerbank::NullCache->new });

=head2 match

=cut

sub match {
    my ( $self, $args ) = @_;
    my $logger = fingerbank::Log::get_logger;

    $self->parseArgs($args);

    my $matcher = fingerbank::SourceMatcher->new(cache => $self->cache);
    $matcher->register_source(fingerbank::Source::LocalDB->new);
    $matcher->register_source(fingerbank::Source::Collector->new);

    return $matcher->match_best($args);
}

=head2 matchEndpoint

=cut

sub matchEndpoint {
    my ( $self, $args ) = @_;
    my $result = $self->match($args);
    return defined($result) ? fingerbank::Model::Endpoint->fromResult($result) : undef;
}

=head2 parseArgs

Parse / Clean query arguments coming in for matching purposes.

=cut

sub parseArgs {
    my ( $self, $args ) = @_;
    my $logger = fingerbank::Log::get_logger;

    # MAC Vendor handling (OUI)
    $args->{'mac_vendor'} = $args->{'mac'};                         # Adding MAC vendor based on the MAC address
    $args->{'mac_vendor'} =~ s/[:|\s|-]//g;                         # Removing separators
    $args->{'mac_vendor'} = lc($args->{'mac_vendor'});              # Lowercasing
    $args->{'mac_vendor'} = substr($args->{'mac_vendor'}, 0, 6);    # Only keep first 6 characters (OUI)
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
