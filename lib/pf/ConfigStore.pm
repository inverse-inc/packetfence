package pf::ConfigStore;

=head1 NAME

pf::ConfigStore

=cut

=head1 DESCRIPTION

pf::ConfigStore

Is the Base class for accessing pf::config::cached

=cut

use Moo;
use namespace::autoclean;
use pf::config::cached;
use Log::Log4perl qw(get_logger);
use List::MoreUtils qw(uniq);
use pfconfig::manager;
use pf::api::jsonrpcclient;
use pf::cluster;

=head1 FIELDS

=head2 cachedConfig

=cut

has cachedConfig =>
  (
   is => 'ro',
   lazy => 1,
   isa => sub {pf::config::cached->isa($_[0])},
   builder => '_buildCachedConfig'
);

has configFile => ( is => 'ro');

has pfconfigNamespace => ( is => 'ro', default => sub {undef});

has default_section => ( is => 'ro');


=head1 METHODS

=head2 validId

validates id

=cut

sub validId { 1; }

=head2 validParam

validate parameter

=cut

sub validParam { 1; }

=head2 _buildCachedConfig

Build the pf::config::cached object

=cut

sub _buildCachedConfig {
    my ($self) = @_;
    my @args = (-file => $self->configFile, -allowempty => 1);
    push @args, -default => $self->default_section if defined $self->default_section;
    return pf::config::cached->new(@args);
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
    my $config = $self->cachedConfig;
    return $config->RewriteConfig();
}

=head2 readAllIds

Get all the sections names

=cut

sub readAllIds {
    my ($self,$itemKey) = @_;
    my @sections = $self->_Sections();
    return \@sections;
}

=head2 readAll

Get all the sections as an array of hash refs

=cut

sub readAll {
    my ($self,$idKey) = @_;
    my $config = $self->cachedConfig;
    my $default_section = $config->{default} if exists $config->{default};
    my @sections;
    foreach my $id ($self->_Sections()) {
        my $section = $self->read($id,$idKey);
        if (defined $default_section &&  $id eq $default_section ) {
            unshift @sections, $section;
        } else {
            push @sections,$section;
        }
    }
    return \@sections;
}

=head2 _Section

The sections for the configurations

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
    $id = $self->_formatId($id);
    return $config->SectionExists($id);
}

=head2 _formatId

format the id

=cut

sub _formatId { return $_[1]; }

=head2 read

reads a section

=cut

sub read {
    my ($self, $id, $idKey ) = @_;
    my $data;
    my $config = $self->cachedConfig;
    $id = $self->_formatId($id);
    if ( $config->SectionExists($id) ) {
        $data = {};
        my @default_params = $config->Parameters($config->{default}) if exists $config->{default};
        $data->{$idKey} = $id if defined $idKey;
        foreach my $param (uniq $config->Parameters($id),@default_params) {
            my $val;
            my @vals = $config->val($id, $param);
            if (@vals == 1 ) {
                $val = $vals[0];
            } else {
                $val = \@vals;
            }
            $data->{$param} = $val;
        }
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
        my $config = $self->cachedConfig;
        my $real_id = $self->_formatId($id);
        if ( $result = $config->SectionExists($real_id) ) {
            $self->cleanupBeforeCommit($id, $assignments);
            $self->_update_section($real_id, $assignments);
        }
    }
    return $result;
}

sub _update_section {
    my ($self, $section, $assignments) = @_;
    my $config = $self->cachedConfig;
    my $default_section = $config->{default} if exists $config->{default};
    my $imported = $config->{imported} if exists $config->{imported};
    my $use_default = $default_section && $section ne $default_section;
    while ( my ($param, $value) = each %$assignments ) {
        my $param_exists = $config->exists($section, $param);
        my $default_value = $config->val($default_section,$param) if ($use_default);
        if(defined $value ) { #If value is defined the update or add to section
            if ( $param_exists ) {
                #If value is defined the update or add to section
                #Only set the value if not equal to the default value otherwise delete it
                if ( defined $default_value && $default_value eq $value) {
                    $config->delval($section, $param, $value);
                } else {
                    $config->setval($section, $param, $value);
                }
            } else {
                #If the value is the same as the default value then do not add
                next if defined $default_value && $default_value eq $value;
                $config->newval($section, $param, $value);
            }
        } else { #Handle deleting param from section
            #if the param exists in the imported config then use that the value in the imported file
            if ( defined $default_value ) {
                $config->setval($section, $param, $default_value);
            } elsif ( $imported && $imported->exists($section, $param) ) {
                $config->setval($section, $param, $imported->val($section, $param));
            } elsif ( $param_exists ) {
                #
                $config->delval($section, $param);
            }
        }
    }
}


=head2 create

To create new section

=cut

sub create {
    my ($self, $id, $assignments) = @_;
    my $config = $self->cachedConfig;
    my $result;
    if ($self->validId($id)) {
        my $real_id = $self->_formatId($id);
        if($result = !$config->SectionExists($id) ) {
            $self->cleanupBeforeCommit($id, $assignments);
            $config->AddSection($real_id);
            $self->_update_section($real_id, $assignments);
        }
    }
    return $result;
}

=head2 update_or_create

=cut

sub update_or_create {
    my ($self, $id, $assignments) = @_;
    if ( $self->hasId($id) ) {
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
    return $self->cachedConfig->DeleteSection($self->_formatId($id));
}

=head2 Copy

Copies a section

=cut

sub copy {
    my ($self,$from,$to) = @_;
    my $result;
    if ($self->validId($to)) {
        $result = $self->cachedConfig->CopySection($self->_formatId($from),$self->_formatId($to));
    }
    return $result;
}

=head2 renameItem

=cut

sub renameItem {
    my ( $self, $old, $new ) = @_;
    my $result;
    if ($self->validId($new)) {
        $result = $self->cachedConfig->RenameSection($self->_formatId($old),$self->_formatId($new));
    }
    return $result;
}

=head2 sortItems

Sorting the items

=cut

sub sortItems {
    my ( $self, $sections ) = @_;
    return $self->cachedConfig->ResortSections(map { $_ = $self->_formatId($_) } @$sections);
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
            $object->{$column} = [ $self->split_list($object->{$column}) ];
        }
    }
}

sub split_list {
    my ($self,$list) = @_;
    return split(/\s*,\s*/,$list);
}

sub join_list {
    my ($self,@list) = @_;
    return join(',',@list);
}

=head2 flatten_list

=cut

sub flatten_list {
    my ( $self,$object,@columns ) = @_;
    foreach my $column (@columns) {
        if (exists $object->{$column} && ref($object->{$column}) eq 'ARRAY') {
            $object->{$column} = $self->join_list(@{$object->{$column}});
        }
    }
}

=head2 commit

=cut

sub commit {
    my ($self) = @_;
    my $result;
    my $error;
    eval {
        $result = $self->rewriteConfig();
    };
    if($@) {
        $error = $@;
        get_logger->error($error);
    }
    unless($result) {
        $error //= "Unable to commit changes to file please run pfcmd fixpermissions and try again";
        $self->rollback();
    }

    $self->commitPfconfig;

    return ($result, $error);
}

sub commitPfconfig {
    my ($self) = @_;

    if(defined($self->pfconfigNamespace)){
        if($cluster_enabled){
            $self->commitCluster();
        }
        else {
            my $manager = pfconfig::manager->new;
            $manager->expire($self->pfconfigNamespace);            
        }
    }
    else{
        get_logger->error("Can't expire pfconfig in ".ref($self)." because the pfconfig namespace is not defined.");
    }
}

sub commitCluster {
    my ($self) = @_;
    my $apiclient = pf::api::jsonrpcclient->new();
    my %data = (
        namespace => $self->pfconfigNamespace,
        conf_file => $self->configFile,
    );
    my $result = $apiclient->notify('expire_cluster', %data );
    unless($result){
        get_logger->error("Couldn't contact API to expire the configuration.");
    }
}

=head2 search

=cut

sub search {
    my ($self, $field, $value) = @_;
    return grep { exists $_->{$field} && defined $_->{$field} && $_->{$field} eq $value  } @{$self->readAll};

}

__PACKAGE__->meta->make_immutable;

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

