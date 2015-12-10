package pf::ConfigStore::Switch;

=head1 NAME

pf::ConfigStore::Switch add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::Switch;

=cut

use Moo;
use namespace::autoclean;
use pf::log;
use pf::file_paths;
use pf::util;
use HTTP::Status qw(:constants is_error is_success);
use List::MoreUtils qw(part any);
use pfconfig::manager;

extends qw(pf::ConfigStore Exporter);
with 'pf::ConfigStore::Hierarchy';


sub configFile { $pf::file_paths::switches_config_file };

sub pfconfigNamespace {'config::Switch'}

sub default_section { undef }

use pf::freeradius;

=head2 Methods

=over

=item cleanupAfterRead

Clean up switch data

=cut

sub cleanupAfterRead {
    my ( $self, $id, $switch ) = @_;
    my $logger = get_logger();

    my $config = $self->cachedConfig;
    # if the uplink attribute is set to dynamic or not set and the group we inherit from is dynamic
    if ( ($switch->{uplink} && $switch->{uplink} eq 'dynamic') ) {
        $switch->{uplink_dynamic} = 'dynamic';
        $switch->{uplink}         = undef;
    }
    $self->expand_list( $switch, 'inlineTrigger' );
    if ( exists $switch->{inlineTrigger} ) {
        $switch->{inlineTrigger} =
          [ map { _splitInlineTrigger($_) } @{ $switch->{inlineTrigger} } ];
    }

    # Config::Inifiles expands the access lists into an array
    # We put it back as a string so it works in the admin UI
    foreach my $attr (keys %$switch){
        if($attr =~ /AccessList$/ && ref($switch->{$attr}) eq 'ARRAY'){
            $switch->{$attr} = join "\n", @{$switch->{$attr}};
        }
    }

}

sub _splitInlineTrigger {
    my ($trigger) = @_;
    my ( $type, $value ) = split( /::/, $trigger );
    return { type => $type, value => $value };
}

=item cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ( $self, $id, $switch ) = @_;

    if ( $switch->{uplink_dynamic} ) {
        $switch->{uplink}         = 'dynamic';
        $switch->{uplink_dynamic} = undef;
    }
    if ( exists $switch->{inlineTrigger} ) {

        # Build string definition for inline triggers (see pf::vlan::isInlineTrigger)
        my $has_always;
        my @triggers = map {
            $has_always = 1 if $_->{type} eq 'always';
            $_->{type} . '::' . ( $_->{value} || '1' )
        } @{ $switch->{inlineTrigger} };
        @triggers = ('always::1') if $has_always;
        $switch->{inlineTrigger} = join( ',', @triggers );
    }

    my $parent_config = $self->full_config_raw($self->_inherit_from($switch));
    use Data::Dumper ; pf::log::get_logger->info(Dumper($switch));
    if($id ne "default") {
        # Put the elements to undef if they are the same as in the inheritance
        while (my ($key, $value) = each %$switch){
            if(defined($value) && $value eq $parent_config->{$key}){
                $switch->{$key} = undef;
            }
        }
    }
}


=item remove

Delete an existing item

=cut

sub remove {
    my ( $self, $id ) = @_;
    if ( defined $id && $id eq 'default' ) {
        return undef;
    }
    return $self->SUPER::remove($id);
}

sub commit {
    my ( $self ) = @_;
    my ($result,$error) = $self->SUPER::commit();
    pfconfig::manager->new->expire('config::Switch');
    return ($result,$error);
}

before rewriteConfig => sub {
    my ($self) = @_;
    my $config = $self->cachedConfig;
    #partioning my their ids
    # default which is also first
    # ip address which is next
    # everything else
    my ($default,$ips,$rest) = part { $_ eq 'default' ? 0  : valid_ip($_) ? 1 : 2 } $config->Sections;
    my @newSections;
    push @newSections, @$default if defined $default;
    push @newSections, sort_ip(@$ips) if defined $ips;
    push @newSections, sort @$rest if defined $rest;
    $config->{sects} = \@newSections;
};


__PACKAGE__->meta->make_immutable;

=back

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

