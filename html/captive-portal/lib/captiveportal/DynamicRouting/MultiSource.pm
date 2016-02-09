package captiveportal::DynamicRouting::MultiSource;

=head1 NAME

captiveportal::DynamicRouting::MultiSource

=head1 DESCRIPTION

MultiSource role to apply on a module to allow it to use multiple sources

=cut

use Moose::Role;
use pf::log;
use List::Util qw(first);

has 'source_id' => (is => 'rw', trigger => \&_build_sources );

has 'sources' => (is => 'rw', default => sub {[]});

around 'source' => sub {
    my ($orig, $self, $source) = @_;

    # We don't modify the setting behavior
    if($source){
        $self->session->{source_id} = $source->id;
        $self->$orig($source);
    }

    # If the source is set in the session we use it.
    if($self->session->{source_id}){
        $source = first { $_->id eq $self->session->{source_id} } @{$self->sources};
        get_logger->info("Found source ".$source->id." in session.");
        return $source;
    }
    else {
        $self->$orig();
    }
};

sub _build_sources {
    my ($self, $source_id, $previous) = @_; 
    my @sources;
    if($source_id eq "_PROFILE_SOURCES_"){
        @sources = ($self->app->profile->getInternalSources, $self->app->profile->getExclusiveSources);
    }
    else {
        my @source_ids = split(/\s*,\s*/, $source_id);
        @sources = map { pf::authentication::getAuthenticationSource($_) } @source_ids;
    }
    
    get_logger->debug(sub { use Data::Dumper ; "Module ".$self->id." is using sources : ".Dumper(\@sources) });
    $self->sources(\@sources);
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

1;

