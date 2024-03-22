package pf::constants::filters;

=head1 NAME

pf::constants::filters

=cut

=head1 DESCRIPTION

Constants for filter engines

=cut

use strict;
use warnings;
use base qw(Exporter);
use Readonly;

use pf::ConfigStore::VlanFilters;
use pf::ConfigStore::RadiusFilters;
use pf::ConfigStore::DhcpFilters;
use pf::ConfigStore::DNS_Filters;
use pf::ConfigStore::SwitchFilters;

our @EXPORT_OK = qw(
  @ACCEPT_FIELDS
  @AIRWATCH_FIELDS
  @ANDROID_FIELDS
  @BASE_FIELDS
  %CONFIGSTORE_MAP
  @DENY_FIELDS
  @DPSK_FIELDS
  %ENGINE_MAP
  %FILTER_NAMES
  %FILTERS_IDENTIFIERS
  @FINGERBANK_FIELDS
  @GOOGLE_FIELDS
  @INTUNE_FIELDS
  @JAMF_FIELDS
  @KANDJI_FIELDS
  @MOBILECONFIG_FIELDS
  @MOBILEIRON_FIELDS
  @NODE_INFO_FIELDS
  @OWNER_FIELDS
  @SECURITY_EVENT_FIELDS
  @SENTINELONE_FIELDS
  @SWITCH_FIELDS
  @WINDOWS_FIELDS
);


our %FILTERS_IDENTIFIERS = (
    VLAN_FILTERS   => "vlan-filters",
    RADIUS_FILTERS => "radius-filters",
    DHCP_FILTERS   => "dhcp-filters",
    DNS_FILTERS    => "dns-filters",
    SWITCH_FILTERS => "switch-filters",
);

our %CONFIGSTORE_MAP = (
    $FILTERS_IDENTIFIERS{VLAN_FILTERS}   => pf::ConfigStore::VlanFilters->new,
    $FILTERS_IDENTIFIERS{RADIUS_FILTERS} => pf::ConfigStore::RadiusFilters->new,
    $FILTERS_IDENTIFIERS{DHCP_FILTERS}   => pf::ConfigStore::DhcpFilters->new,
    $FILTERS_IDENTIFIERS{DNS_FILTERS}    => pf::ConfigStore::DNS_Filters->new,
    $FILTERS_IDENTIFIERS{SWITCH_FILTERS}    => pf::ConfigStore::SwitchFilters->new,
);

our %ENGINE_MAP = (
    $FILTERS_IDENTIFIERS{VLAN_FILTERS}   => "FilterEngine::VlanScopes",
    $FILTERS_IDENTIFIERS{RADIUS_FILTERS} => "FilterEngine::RadiusScopes",
    $FILTERS_IDENTIFIERS{DHCP_FILTERS}   => "FilterEngine::DhcpScopes",
    $FILTERS_IDENTIFIERS{DNS_FILTERS}    => "FilterEngine::DNS_Scopes",
    $FILTERS_IDENTIFIERS{SWITCH_FILTERS}    => "FilterEngine::SwitchScopes",
);

our %FILTER_NAMES = (
    vlan   => "VLAN filters",
    radius => "RADIUS filters",
    dhcp   => "DHCP filters",
    dns    => "DNS filters",
    switch => "Switch filters",
);

our @BASE_FIELDS = qw(
  ifIndex
  mac
  connection_type
  connection_sub_type
  username
  ssid
  vlan
  wasInline
  user_role
  time
  action
);

our @FINGERBANK_FIELDS = qw(
  fingerbank_info.device_fq
  fingerbank_info.device_hierarchy_names
  fingerbank_info.device_hierarchy_ids
  fingerbank_info.score
  fingerbank_info.version
  fingerbank_info.mobile
);

our @NODE_INFO_FIELDS = qw(
  node_info.autoreg
  node_info.status
  node_info.bypass_vlan
  node_info.bandwidth_balance
  node_info.regdate
  node_info.bypass_role
  node_info.device_class
  node_info.device_type
  node_info.device_version
  node_info.device_score
  node_info.pid
  node_info.machine_account
  node_info.category
  node_info.category_id
  node_info.mac
  node_info.last_arp
  node_info.last_dhcp
  node_info.user_agent
  node_info.computername
  node_info.dhcp_fingerprint
  node_info.detect_date
  node_info.voip
  node_info.notes
  node_info.time_balance
  node_info.sessionid
  node_info.dhcp_vendor
  node_info.unregdate
  node_info.last_connection_type
);

our @KANDJI_FIELDS = qw(
  kandji.device_id
  kandji.device_name
  kandji.model
  kandji.serial_number
  kandji.platform
  kandji.os_version
  kandji.supplemental_build_version
  kandji.supplemental_os_version_extra
  kandji.last_check_in
  kandji.user
  kandji.asset_tag
  kandji.blueprint_id
  kandji.mdm_enabled
  kandji.agent_installed
  kandji.is_missing
  kandji.is_removed
  kandji.agent_version
  kandji.first_enrollment
  kandji.last_enrollment
  kandji.blueprint_name
  kandji.lost_mode_status
);

our @INTUNE_FIELDS = qw(
  intune.udid
  intune.operatingSystem
  intune.freeStorageSpaceInBytes
  intune.remoteAssistanceSessionErrorDetails
  intune.exchangeAccessState
  intune.managementAgent
  intune.deviceName
  intune.ethernetMacAddress
  intune.userDisplayName
  intune.managementCertificateExpirationDate
  intune.userPrincipalName
  intune.enrolledDateTime
  intune.emailAddress
  intune.deviceRegistrationState
  intune.manufacturer
  intune.exchangeAccessStateReason
  intune.deviceEnrollmentType
  intune.notes
  intune.azureADRegistered
  intune.remoteAssistanceSessionUrl
  intune.managedDeviceName
  intune.androidSecurityPatchLevel
  intune.isEncrypted
  intune.userId
  intune.activationLockBypassCode
  intune.easDeviceId
  intune.subscriberCarrier
  intune.jailBroken
  intune.exchangeLastSuccessfulSyncDateTime
  intune.physicalMemoryInBytes
  intune.complianceGracePeriodExpirationDateTime
  intune.serialNumber
  intune.complianceState
  intune.lastSyncDateTime
  intune.deviceHealthAttestationState
  intune.meid
  intune.configurationManagerClientEnabledFeatures
  intune.id
  intune.azureADDeviceId
  intune.requireUserEnrollmentApproval
  intune.imei
  intune.totalStorageSpaceInBytes
  intune.osVersion
  intune.wiFiMacAddress
  intune.phoneNumber
  intune.iccid
  intune.easActivated
  intune.easActivationDateTime
  intune.partnerReportedThreatState
  intune.model
  intune.deviceCategoryDisplayName
  intune.managedDeviceOwnerType
  intune.isSupervised
);

our @GOOGLE_FIELDS = qw(
  deviceId
  serialNumber
  status
  lastSync
  supportEndDate
  annotatedUser
  annotatedLocation
  notes
  model
  meid
  orderNumber
  willAutoRenew
  osVersion
  platformVersion
  firmwareVersion
  macAddress
  bootMode
  lastEnrollmentTime
  kind
  ethernetMacAddress
  annotatedAssetId
  etag
  systemRamTotal
  autoUpdateExpiration
  ethernetMacAddress0
  dockMacAddress
  manufactureDate
  orgUnitPath
  tpmVersionInfo.family
  tpmVersionInfo.specLevel
  tpmVersionInfo.manufacturer
  tpmVersionInfo.tpmModel
  tpmVersionInfo.firmwareVersion
  tpmVersionInfo.vendorSpecific
  orgUnitId
  osUpdateStatus.state
  osUpdateStatus.targetOsVersion
  osUpdateStatus.targetKioskAppVersion
  osUpdateStatus.updateTime
  osUpdateStatus.updateCheckTime
  osUpdateStatus.rebootTime
  firstEnrollmentTime
  lastDeprovisionTimestamp
  deprovisionReason
  deviceLicenseType
);

our @SWITCH_FIELDS = qw(
  switch._ExternalPortalEnforcement
  switch._RoleMap
  switch._SNMPAuthPasswordRead
  switch._SNMPAuthPasswordTrap
  switch._SNMPAuthPasswordWrite
  switch._SNMPAuthProtocolRead
  switch._SNMPAuthProtocolTrap
  switch._SNMPAuthProtocolWrite
  switch._SNMPCommunityRead
  switch._SNMPCommunityTrap
  switch._SNMPCommunityWrite
  switch._SNMPEngineID
  switch._SNMPPrivPasswordRead
  switch._SNMPPrivPasswordTrap
  switch._SNMPPrivPasswordWrite
  switch._SNMPPrivProtocolRead
  switch._SNMPPrivProtocolTrap
  switch._SNMPPrivProtocolWrite
  switch._SNMPUseConnector
  switch._SNMPUserNameRead
  switch._SNMPUserNameTrap
  switch._SNMPUserNameWrite
  switch._SNMPVersion
  switch._SNMPVersionTrap
  switch._UrlMap
  switch._VlanMap
  switch._VoIPEnabled
  switch._cliEnablePwd
  switch._cliPwd
  switch._cliTransport
  switch._cliUser
  switch._coaPort
  switch._controllerIp
  switch._deauthMethod
  switch._disconnectPort
  switch._id
  switch._inlineTrigger
  switch._ip
  switch._macSearchesMaxNb
  switch._macSearchesSleepInterval
  switch._mode
  switch._radiusDeauthUseConnector
  switch._roles
  switch._switchIp
  switch._switchMac
  switch._type
  switch._uplink
  switch._useCoA
  switch._vlans
  switch._wsPwd
  switch._wsTransport
  switch._wsUser
  switch._group
);

our @OWNER_FIELDS = qw(
  owner.pid
  owner.firstname
  owner.lastname
  owner.email
  owner.telephone
  owner.company
  owner.address
  owner.notes
  owner.sponsor
  owner.anniversary
  owner.birthday
  owner.gender
  owner.lang
  owner.nickname
  owner.cell_phone
  owner.work_phone
  owner.title
  owner.building_number
  owner.apartment_number
  owner.room_number
  owner.custom_field_1
  owner.custom_field_2
  owner.custom_field_3
  owner.custom_field_4
  owner.custom_field_5
  owner.custom_field_6
  owner.custom_field_7
  owner.custom_field_8
  owner.custom_field_9
  owner.portal
  owner.source
  owner.nodes
  owner.password
  owner.valid_from
  owner.expiration
  owner.access_duration
  owner.access_level
  owner.can_sponsor
  owner.unregdate
  owner.category
);

our @SECURITY_EVENT_FIELDS = qw(
  security_event.id
  security_event.start_date
  security_event.release_date
  security_event.status
  security_event.ticket_ref
  security_event.notes
);

our @JAMF_FIELDS = qw(

);

our @ACCEPT_FIELDS;
our @AIRWATCH_FIELDS;
our @ANDROID_FIELDS;
our @DENY_FIELDS;
our @DPSK_FIELDS;
our @MOBILECONFIG_FIELDS;
our @MOBILEIRON_FIELDS;
our @SENTINELONE_FIELDS;
our @WINDOWS_FIELDS;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
