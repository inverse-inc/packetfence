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
use List::MoreUtils qw(part);
use pfconfig::manager;

extends qw(pf::ConfigStore Exporter);

sub configFile {$switches_config_file}

sub pfconfigNamespace {'config::Switch'}

our ( $switches_cached_config, %SwitchConfig );
our @EXPORT = qw(%SwitchConfig);
use pf::freeradius;

$switches_cached_config = pf::config::cached->new(
    -file         => $switches_config_file,
    -allowempty   => 1,
    -default      => 'default',
    -onfilereload => [
        on_switches_reload => sub {
            my ( $config, $name ) = @_;
            populateSwitchConfig( $config, $name );
        },
    ],
    -onfilereloadonce => [
        reload_switches_conf => sub {
            my ( $config, $name ) = @_;
            freeradius_populate_nas_config( \%SwitchConfig, $config->GetLastModTimestamp );
        }
    ],
    -oncachereload => [
        on_cached_overlay_reload => sub {
            my ( $config, $name ) = @_;
            my $data = $config->fromCacheForDataUntainted("SwitchConfig");
            if($data) {
                %SwitchConfig = %$data;
            } else {
                #if not found then repopulate switch
                $config->_callFileReloadCallbacks();
            }
        },
    ]
);

sub populateSwitchConfig {
    my ( $config, $name ) = @_;
    $config->toHash( \%SwitchConfig );
    $config->cleanupWhitespace( \%SwitchConfig );
    foreach my $switch ( values %SwitchConfig ) {

        # transforming uplink and inlineTrigger to arrays
        foreach my $key (qw(uplink inlineTrigger)) {
            my $value = $switch->{$key} || "";
            $switch->{$key} = [ split /\s*,\s*/, $value ];
        }

        # transforming vlans and roles to hashes
        my %merged = ( Vlan => {}, Role => {}, AccessList => {} );
        foreach my $key ( grep {/(Vlan|Role|AccessList)$/} keys %{$switch} ) {
            next unless my $value = $switch->{$key};
            if ( my ( $type_key, $type ) = ( $key =~ /^(.+)(Vlan|Role|AccessList)$/ ) ) {
                $merged{$type}{$type_key} = $value;
            }
        }
        $switch->{roles}        = $merged{Role};
        $switch->{vlans}        = $merged{Vlan};
        $switch->{access_lists} = $merged{AccessList};
        $switch->{VoIPEnabled} = (
            $switch->{VoIPEnabled} =~ /^\s*(y|yes|true|enabled|1)\s*$/i
            ? 1
            : 0
        );
        $switch->{mode} = lc( $switch->{mode} );
        $switch->{'wsUser'} ||= $switch->{'htaccessUser'};
        $switch->{'wsPwd'} ||= $switch->{'htaccessPwd'} || '';
        foreach my $cli_default (qw(EnablePwd Pwd User)) {
            $switch->{"cli${cli_default}"}
              ||= $switch->{"telnet${cli_default}"};
        }
        foreach my $snmpDefault (
            qw(communityRead communityTrap communityWrite version)) {
            my $snmpkey = "SNMP" . ucfirst($snmpDefault);
            $switch->{$snmpkey} ||= $switch->{$snmpDefault};
        }
    }
    $SwitchConfig{'127.0.0.1'} = {
        %{ $SwitchConfig{default} },
        type              => 'PacketFence',
        mode              => 'production',
        uplink            => ['dynamic'],
        SNMPVersionTrap   => '1',
        SNMPCommunityTrap => 'public'
    };
    $config->cacheForData->set( "SwitchConfig", \%SwitchConfig );
}

sub _buildCachedConfig { $switches_cached_config }

=head2 Methods

=over

=item cleanupAfterRead

Clean up switch data

=cut

sub cleanupAfterRead {
    my ( $self, $id, $switch ) = @_;
    my $logger = get_logger();

    if ( $switch->{uplink} && $switch->{uplink} eq 'dynamic' ) {
        $switch->{uplink_dynamic} = 'dynamic';
        $switch->{uplink}         = undef;
    }
    $self->expand_list( $switch, 'inlineTrigger' );
    if ( exists $switch->{inlineTrigger} ) {
        $switch->{inlineTrigger} =
          [ map { _splitInlineTrigger($_) } @{ $switch->{inlineTrigger} } ];
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

