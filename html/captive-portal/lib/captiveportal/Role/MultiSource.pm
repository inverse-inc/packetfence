package captiveportal::Role::MultiSource;

=head1 NAME

captiveportal::Role::MultiSource

=head1 DESCRIPTION

MultiSource role to apply on a module to allow it to use multiple sources

=cut

use Moose::Role;
use pf::log;
use List::Util qw(first);
use List::MoreUtils qw(uniq);
use pf::constants;

has 'source_id' => (is => 'rw', trigger => \&_build_sources );

has 'sources' => (is => 'rw', default => \&_build_sources);

has 'multi_source_types' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub{[]});

has 'multi_source_auth_classes' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub{[]});

has 'multi_source_object_classes' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub{[]});

=head2 display

The module should only be displayed if it has sources

=cut

sub display {
    my ($self) = @_;
    return @{$self->sources} ? $TRUE : $FALSE;
}

=head2 around source

Record the current active source after it has been set

=cut

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
        if($source){
            get_logger->info("Found source ".$source->id." in session.");
            return $source;
        }
        else {
            get_logger->warn("Cannot find current authentication source, restarting registration process.");
            $self->app->redirect("/logout");
            $self->detach();
        }
    }
    else {
        $self->$orig();
    }
};

=head2 _build_sources

Build the sources from the source_id and the filtering attributes
If source_id is not defined or empty, the filtering attributes will be applied to all the connection profile sources
Otherwise, the sources defined in source_id will be used even if they are not part of the connection profile

=cut

sub _build_sources {
    my ($self, $source_id, $previous) = @_; 
    my @sources;
    
    # First sources of the array are the ones we defined manually
    if(defined($source_id) && $source_id){
        my @source_ids = split(/\s*,\s*/, $source_id);
        push @sources, map { pf::authentication::getAuthenticationSource($_) } @source_ids;
    }
    else {
        my @sources_by_type = map { $self->app->profile->getSourcesByType($_) } @{$self->multi_source_types};
        my @sources_by_auth_class = map { $self->app->profile->getSourcesByClass($_) } @{$self->multi_source_auth_classes};
        my @sources_by_object_class = map { $self->app->profile->getSourcesByObjectClass($_) } @{$self->multi_source_object_classes};
        push @sources, (@sources_by_type, @sources_by_auth_class, @sources_by_object_class);
        
        @sources = uniq(@sources);
    
        my %sources_map = map { $_->id => $_ } @sources;
    
        # we respect the order defined in the portal module, then the one in the connection profile for the sources that are in it.
        my @ordered_sources;
        foreach my $source_id (@{$self->app->profile->getSources()}){
            if(defined($sources_map{$source_id})){
                push @ordered_sources, $sources_map{$source_id};
                delete $sources_map{$source_id};
            }
        }
    
        # we push the remaining sources at the end
        while(my ($source_id, $source) = each(%sources_map)){
            push @ordered_sources, $source;
        }
        @sources = @ordered_sources;
    }

    get_logger->debug(sub { "Module ".$self->id." is using sources : ".join(',', (map {$_->id} @sources)) });
    $self->sources(\@sources);
    return \@sources;
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

