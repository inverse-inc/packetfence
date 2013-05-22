package pf::ConfigStore;

=head1 NAME

pf::ConfigStore

=cut

=head1 DESCRIPTION

pf::ConfigStore

Is the Base class for accessing pf::config::cached

=cut

use Moose;
use namespace::autoclean;
use pf::config::cached;
use Log::Log4perl qw(get_logger);
use List::MoreUtils qw(uniq);

=head1 FIELDS

=head2 cachedConfig

=cut

has cachedConfig =>
  (
   is => 'ro',
   lazy => 1,
   isa => 'pf::config::cached',
   builder => '_buildCachedConfig'
);

has configFile => ( is => 'ro');

has default_section => ( is => 'ro');


=head1 METHODs

=head2 _buildCachedConfig

=cut

sub _buildCachedConfig {
    my ($self) = @_;
    my @args = (-file => $self->configFile, -allowempty => 1);
    push @args, -default => $self->default_section if defined $self->default_section;
    return pf::config::cached->new(@args);
}


=head2 readConfig

=cut

sub readConfig {
    my ($self) = @_;
    my $config = $self->cachedConfig;
    return $config->ReadConfig();
}

=head2 rollback

Rollback changes that were made

=cut

sub rollback {
    my ($self) = @_;
    my $config = $self->cachedConfig;
    return $config->Rollback();
}

=head2 rewriteConfig

Save the cached config

=cut

sub rewriteConfig {
    my ($self) = @_;
    my $logger = get_logger();
    my $config = $self->cachedConfig;
    return $config->RewriteConfig();
}

=head2 readAllIds

Get all the sections names

=cut

sub readAllIds {
    my ($self) = @_;
    my $config = $self->cachedConfig;
    my @sections = $self->_Sections();
    return \@sections;
}

=head2 readAll

Get all the sections as an array of hash refs

=cut

sub readAll {
    my ( $self) = @_;
    my $config = $self->cachedConfig;
    my @sections;
    foreach my $id ($self->_Sections()) {
        my %section = ( $self->idKey() => $id );
        foreach my $param ($config->Parameters($id)) {
            $section{$param} = $config->val( $id, $param);
        }
        $self->cleanupAfterRead($id,\%section);
        if ($id =~ m/defaults?/) {
            unshift @sections, \%section;
        } else {
            push @sections,\%section;
        }
    }
    return \@sections;
}

=head2 _Section

=cut

sub _Sections {
    my ($self) = @_;
    return $self->cachedConfig->Sections();
}

=head2 hasId

If config has a section

=cut

sub hasId {
    my ($self, $id ) = @_;
    my $config = $self->cachedConfig;
    return $config->SectionExists($id);
}

=head2 read

reads a section

=cut

sub read {
    my ($self, $id ) = @_;
    my $data;
    my $config = $self->cachedConfig;
    if ( $config->SectionExists($id) ) {
        my @default_params = $config->Parameters($config->{default}) if exists $config->{default};
        my %item;
        foreach my $param (uniq $config->Parameters($id),@default_params) {
            $item{$param} = $config->val( $id, $param);
        }
        $data = \%item;
        $self->cleanupAfterRead($id,$data);
    }
    return $data;
}

=head2 update

Update/edit/modify an existing section

=cut

sub update {
    my ($self, $id, $assignments) = @_;
    my $result;
    if ($id ne 'all') {
        $self->cleanupBeforeCommit($id, $assignments);
        my $config = $self->cachedConfig;
        if ( $config->SectionExists($id) ) {
            my $default_section = $config->{default} if exists $config->{default};
            my $default_value;
            while ( my ($param, $value) = each %$assignments ) {
                if ( $config->exists($id, $param) ) {
                    if(defined($value) &&
                        !($default_section && ($default_value = $config->val($default_section,$param)) && $default_value eq $value)
                        ) {
                        $config->setval($id, $param, $value);
                    } else {
                        $config->delval($id, $param);
                    }
                } elsif(defined($value)) {
                    next if $default_section &&  ($default_value = $config->val($default_section,$param)) && $default_value eq $value;
                    $config->newval($id, $param, $value);
                }
            }
            $result = 1;
        }
    }
    return $result;
}


=head2 create

To create new section

=cut

sub create {
    my ($self, $id, $assignments) = @_;
    $self->cleanupBeforeCommit($id, $assignments);
    my $config = $self->cachedConfig;
    my $result;
    if($result = !$config->SectionExists($id) ) {
        $config->AddSection($id);
        my $default_section = $config->{default} if exists $config->{default};
        my $default_value;
        while ( my ($param, $value) = each %$assignments ) {
            next if $default_section &&  ($default_value = $config->val($default_section,$param)) && $default_value eq $value;
            $config->newval( $id, $param, defined $value ? $value : '' );
        }
    }
    return $result;
}

=head2 update_or_create

=cut

sub update_or_create {
    my ($self, $id, $assignments) = @_;
    my $config = $self->cachedConfig;
    if ( $config->SectionExists($id) ) {
        return $self->update($id, $assignments);
    } else {
        return $self->create($id, $assignments);
    }
}


=head2 remove

Removes an existing item

=cut

sub remove {
    my ($self, $id) = @_;
    my $config = $self->cachedConfig;
    return $config->DeleteSection($id);
}

=head2 Copy

Copies a section

=cut

sub copy {
    my ($self,$from,$to) = @_;
    my $logger = get_logger();
    my ($status,$status_msg);
    my $config = $self->cachedConfig;
    return $config->CopySection($from,$to);
}

=head2 renameItem

=cut

sub renameItem {
    my ( $self, $old, $new ) = @_;
    my $config = $self->cachedConfig;
    return $config->RenameSection($old,$new);
}

=head2 sortItems

Sorting the items

=cut

sub sortItems {
    my ( $self, $sections ) = @_;
    my $config = $self->cachedConfig;
    return $config->ResortSections(@$sections);
}

=head2 cleanupAfterRead

=cut

sub cleanupAfterRead { }

=head2 cleanupBeforeCommit

=cut

sub cleanupBeforeCommit { }

=head2 expand_list

=cut

sub expand_list {
    my ( $self,$object,@columns ) = @_;
    foreach my $column (@columns) {
        if (exists $object->{$column}) {
            my @items = split(/\s*,\s*/,$object->{$column});
            $object->{$column} = \@items;
        }
    }
}

=head2 flatten_list

=cut

sub flatten_list {
    my ( $self,$object,@columns ) = @_;
    foreach my $column (@columns) {
        if (exists $object->{$column} && ref($object->{$column}) eq 'ARRAY') {
            $object->{$column} = join(',',@{$object->{$column}});
        }
    }
}

=head2 commit

=cut

sub commit {
    my ($self) = @_;
    my $result;
    eval {
        $result = $self->rewriteConfig();
    };
    unless($result) {
        $self->rollback();
    }
    return $result;
}

__PACKAGE__->meta->make_immutable;

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

