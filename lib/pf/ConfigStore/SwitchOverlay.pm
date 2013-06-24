package pf::ConfigStore::SwitchOverlay;
=head1 NAME

pf::ConfigStore::SwitchOverlay add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::SwitchOverlay;

=cut

use Moo;
use namespace::autoclean;
use pf::log;
use pf::file_paths;
use pf::ConfigStore::Switch;
use HTTP::Status qw(:constants is_error is_success);
our (%SwitchConfig, $switches_overlay_cached_config);

extends qw(pf::ConfigStore Exporter);

our @EXPORT = qw(%SwitchConfig);

$switches_overlay_cached_config = pf::config::cached->new(
    -file => $switches_overlay_file,
    -allowempty => 1,
    -import => $pf::ConfigStore::Switch::switches_cached_config,
    -default => 'default',
    -onfilereload => [
        on_switches_reload => sub  {
            my ($config, $name) = @_;
            $config->toHash(\%SwitchConfig);
            $config->cleanupWhitespace(\%SwitchConfig);
            my $imported = $config->{imported};
            my @leftover = grep { !$imported->SectionExists($_) }   $config->Sections();
            delete @SwitchConfig{@leftover};
            foreach my $switch (values %SwitchConfig) {
                # transforming uplink and inlineTrigger to arrays
                foreach my $key (qw(uplink inlineTrigger)) {
                    my $value = $switch->{$key} || "";
                    $switch->{$key} = [split /\s*,\s*/,$value ];
                }
                # transforming vlans and roles to hashes
                my %merged = ( Vlan => {}, Role => {});
                foreach my $key ( grep { /(Vlan|Role)$/ } keys %{$switch}) {
                    next unless my $value = $switch->{$key};
                    if (my ($type_key,$type) = ($key =~ /^(.+)(Vlan|Role)$/)) {
                        $merged{$type}{$type_key} = $value;
                    }
                }
                $switch->{roles} = $merged{Role};
                $switch->{vlans} = $merged{Vlan};
                $switch->{VoIPEnabled} =  ($switch->{VoIPEnabled} =~ /^\s*(y|yes|true|enabled|1)\s*$/i ? 1 : 0);
                $switch->{mode} =  lc($switch->{mode});
                $switch->{'wsUser'} ||= $switch->{'htaccessUser'};
                $switch->{'wsPwd'}  ||= $switch->{'htaccessPwd'} || '';
                foreach my $cli_default (qw(EnablePwd Pwd User)) {
                    $switch->{"cli${cli_default}"}  ||= $switch->{"telnet${cli_default}"};
                }
                foreach my $snmpDefault (qw(communityRead communityTrap communityWrite version)) {
                    my $snmpkey = "SNMP" . ucfirst($snmpDefault);
                    $switch->{$snmpkey}  ||= $switch->{$snmpDefault};
                }
            }
            $SwitchConfig{'127.0.0.1'} = { %{$SwitchConfig{default}}, type => 'PacketFence', mode => 'production', uplink => ['dynamic'], SNMPVersionTrap => '1', SNMPCommunityTrap => 'public'};
            $config->cache->set("SwitchConfig",\%SwitchConfig);
        },
    ],
    -oncachereload => [
        on_cached_overlay_reload => sub  {
            my ($config, $name) = @_;
            my $data = $config->cache->get("SwitchConfig");
            if($data) {
                %SwitchConfig = %$data;
            }
        },
    ]
);

=head1 METHODS

=head2 _buildConfigStore

=cut

sub _buildCachedConfig { $switches_overlay_cached_config };

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

