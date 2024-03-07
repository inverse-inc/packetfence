<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs lazy>
      <template v-slot:tabs-end>
        <div class="text-right mr-3">
          <base-input-toggle-advanced-mode v-model="advancedMode" label-left />
        </div>
      </template>
      <base-form-tab :title="$i18n.t('Definition')" active>

        <form-group-identifier namespace="id"
          :column-label="$i18n.t('IP Address/MAC Address/Range (CIDR)')"
        />

        <form-group-description namespace="description"
          :column-label="$i18n.t('Description')"
        />

        <form-group-type namespace="type"
          :column-label="$i18n.t('Type')"
        />

        <form-group-mode namespace="mode"
          :column-label="$i18n.t('Mode')"
        />

        <form-group-group namespace="group"
          :column-label="$i18n.t('Switch Group')"
        />

        <form-group-deauthentication-method namespace="deauthMethod"
          :column-label="$i18n.t('Deauthentication Method')"
        />

        <form-group-deauth-on-previous namespace="deauthOnPrevious"
          :column-label="$i18n.t('Deauth on previous switch')"
          :text="$i18n.t('This option parameter will allow you to do the deauthentication/CoA on the previous switch where the device was connected.')"
          enabled-value="Y"
          disabled-value="N"
        />

        <form-group-external-portal-enforcement namespace="ExternalPortalEnforcement"
          v-show="supports(['ExternalPortal'])"
          :column-label="$i18n.t('External Portal Enforcement')"
          :text="$i18n.t('Enable external portal enforcement when supported by network equipment.')"
        />

        <form-group-voip-enabled namespace="VoIPEnabled"
          :column-label="$i18n.t('VoIP')"
        />

        <form-group-voip-lldp-detect namespace="VoIPLLDPDetect"
          v-show="supports(['Lldp'])"
          :column-label="$i18n.t('VoIP LLDP Detect')"
          :text="$i18n.t('Detect VoIP with a SNMP request in the LLDP MIB.')"
        />

        <form-group-voip-cdp-detect namespace="VoIPCDPDetect"
          v-show="supports(['Cdp'])"
          :column-label="$i18n.t('VoIP CDP Detect')"
          :text="$i18n.t('Detect VoIP with a SNMP request in the CDP MIB.')"
        />

        <form-group-voip-dhcp-detect namespace="VoIPDHCPDetect"
          :column-label="$i18n.t('VoIP DHCP Detect')"
          :text="$i18n.t('Detect VoIP with the DHCP Fingerprint.')"
        />

        <form-group-uplink-dynamic namespace="uplink_dynamic"
          v-show="supports(['WiredMacAuth', 'WiredDot1x'])"
          :column-label="$i18n.t('Dynamic Uplinks')"
          :text="$i18n.t('Dynamically lookup uplinks.')"
        />

        <form-group-uplink namespace="uplink"
          v-show="supports(['WiredMacAuth', 'WiredDot1x']) && !isUplinkDynamic"
          :column-label="$i18n.t('Static Uplinks')"
          :text="$i18n.t('Comma-separated list of the switch uplinks.')"
        />

        <div class="alert alert-warning">
          <strong>{{ $i18n.t('Note:') }}</strong>
          {{ $i18n.t('Some RADIUS related settings have been moved to the RADIUS tab') }}
        </div>

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Roles')">

        <div v-if="!advancedMode && !supports(['RadiusDynamicVlanAssignment', 'RoleBasedEnforcement', 'VPNRoleBasedEnforcement', 'AccessListBasedEnforcement', 'ExternalPortal'])"
          class="alert alert-warning"
        >
          <strong>{{ $i18n.t('Note:') }}</strong>
          {{ $i18n.t('Choose a Switch type, or enable advanced mode to manage roles.') }}
        </div>

        <b-tabs lazy v-else>

          <base-form-tab v-if="supports(['RadiusDynamicVlanAssignment'])"
            :title="$i18n.t('VLAN ID')" active>
            <b-card class="mb-3 pb-0" no-body>
              <b-card-header>
                <h4 class="mb-0" v-t="'Role mapping by VLAN ID'"></h4>
              </b-card-header>
              <div class="card-body pb-0">
                <form-group-toggle-vlan-map namespace="VlanMap"
                  :column-label="$i18n.t('Role by VLAN ID')"
                />

                <template v-if="isVlanMap">
                  <form-group-role-map-vlan v-for="role in roles" :key="`${role}Vlan`" :namespace="`${role}Vlan`"
                    :column-label="role"
                  />
                </template>
              </div>
            </b-card>
          </base-form-tab>

          <base-form-tab v-if="supports(['RoleBasedEnforcement'])"
            :title="$i18n.t('Switch Role')">
            <b-card class="mb-3 pb-0" no-body>
              <b-card-header>
                <h4 class="mb-0" v-t="'Role mapping by Switch Role'"></h4>
              </b-card-header>
              <div class="card-body pb-0">
                <form-group-toggle-role-map namespace="RoleMap"
                  :column-label="$i18n.t('Role by Switch Role')"
                />

                <template v-if="isRoleMap">
                  <form-group-role-map-role v-for="role in roles" :key="`${role}Role`" :namespace="`${role}Role`"
                    :column-label="role"
                  />
                </template>
              </div>
            </b-card>
          </base-form-tab>

          <base-form-tab v-if="supports(['VPNRoleBasedEnforcement'])"
            :title="$i18n.t('Vpn Role')">
            <b-card class="mb-3 pb-0" no-body>
              <b-card-header>
                <h4 class="mb-0" v-t="'Role mapping by Vpn Role'"></h4>
              </b-card-header>
              <div class="card-body pb-0">
                <form-group-toggle-access-list-map namespace="VpnMap"
                  :column-label="$i18n.t('Role by Vpn Role')"
                />

                <template v-if="isVpnMap">
                  <form-group-role-map-vpn v-for="role in roles" :key="`${role}Vpn`" :namespace="`${role}Vpn`"
                    :column-label="role"
                  />
                </template>
              </div>
            </b-card>
          </base-form-tab>

          <base-form-tab v-if="supports(['AccessListBasedEnforcement'])"
            :title="$i18n.t('Access List')">
            <b-card class="mb-3 pb-0" no-body>
              <b-card-header>
                <h4 class="mb-0" v-t="'Role mapping by Access List'"></h4>
              </b-card-header>
              <div class="card-body pb-0">
                <form-group-toggle-access-list-map namespace="AccessListMap"
                  :column-label="$i18n.t('Role by Access List')"
                  :text="$i18n.t('Defining an ACL will supersede the one defined directly in the role configuration.')"
                />

                <template v-if="isAccessListMap">
                  <form-group-role-map-access-list v-for="role in roles" :key="`${role}AccessList`" :namespace="`${role}AccessList`"
                    :column-label="role"
                  />
                </template>
              </div>
              <b-card-header>
                <h4 class="mb-0" v-t="'Interface mapping by Access List'"></h4>
              </b-card-header>
              <div class="card-body pb-0">
                <form-group-toggle-interface-map namespace="InterfaceMap"
                  :column-label="$i18n.t('Interface by Access List')"
                  :text="$i18n.t('Define the interface name where the acl associated to the role will be applied.')"
                />

                <template v-if="isInterfaceMap">
                  <form-group-role-map-interface v-for="role in roles" :key="`${role}Interface`" :namespace="`${role}Interface`"
                    :column-label="role"
                  />
                </template>
              </div>
            </b-card>
          </base-form-tab>

          <base-form-tab v-if="supports(['ExternalPortal'])"
            :title="$i18n.t('Web Auth URL')">
            <b-card class="mb-3 pb-0" no-body>
              <b-card-header>
                <h4 class="mb-0" v-t="'Role mapping by Web Auth URL'"></h4>
              </b-card-header>
              <div class="card-body pb-0">
                <form-group-toggle-url-map namespace="UrlMap"
                  :column-label="$i18n.t('Role by Web Auth URL')"
                />

                <template v-if="isUrlMap">
                  <form-group-role-map-url v-for="role in roles" :key="`${role}Url`" :namespace="`${role}Url`"
                    :column-label="role"
                  />
                </template>
              </div>
            </b-card>
          </base-form-tab>

          <base-form-tab
            :title="$i18n.t('Network CIDR')">
            <b-card class="mb-3 pb-0" no-body>
              <b-card-header>
                <h4 class="mb-0" v-t="'Role mapping by Network CIDR'"></h4>
              </b-card-header>
              <div class="card-body pb-0">
                <form-group-toggle-network-map namespace="NetworkMap"
                  :column-label="$i18n.t('Role by Network CIDR')"
                />

                <template v-if="isNetworkMap">
                  <b-form-group v-for="role in roles" :key="`${role}Network`"
                    :label="role" label-cols="3"
                    class="base-form-group"
                  >
                    <b-input-group>
                      <b-row class="w-100 mx-0 mb-1 px-0" align-v="center" no-gutters>
                        <b-col sm="6" align-self="center">
                          <input-role-map-network :namespace="`${role}Network`"
                            :disabled="form[`${role}NetworkFrom`] !== 'static'" />
                        </b-col>
                        <b-col sm="6" align-self="center" class="pl-1">
                          <input-toggle-network-from :namespace="`${role}NetworkFrom`" />
                        </b-col>
                      </b-row>
                    </b-input-group>
                  </b-form-group>
                </template>
              </div>
            </b-card>
          </base-form-tab>

        </b-tabs>
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Inline')">

        <form-group-inline-trigger namespace="inlineTrigger"
          :column-label="$i18n.t('Inline Conditions')"
          :text="$i18n.t('Set inline mode if any of the conditions are met.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('RADIUS')" v-if="supports(['WiredMacAuth', 'WiredDot1x', 'WirelessMacAuth', 'WirelessDot1x', 'VPN'])">

        <form-group-radius-secret namespace="radiusSecret"
          :column-label="$i18n.t('Secret Passphrase')"
        />

        <form-group-use-coa namespace="useCoA"
          :column-label="$i18n.t('Use CoA')"
          :text="$i18n.t('Use CoA when available to deauthenticate the user. When disabled, RADIUS Disconnect will be used instead if it is available.')"
        />

        <form-group-radius-deauth-use-connector namespace="radiusDeauthUseConnector"
          :column-label="$i18n.t('Use Connector For Deauth')"
          :text="$i18n.t('Use the available PacketFence connectors to perform RADIUS deauth (access reevaluation). By default, a local connector is hosted on this server.')"
        />

        <form-group-controller-ip namespace="controllerIp"
          v-show="supports(['WirelessMacAuth', 'WirelessDot1x'])"
          :column-label="$i18n.t('Controller IP Address')"
          :text="$i18n.t('Use instead this IP address for de-authentication requests. Normally used for Wi-Fi only.')"
        />

        <form-group-disconnect-port namespace="disconnectPort"
          v-show="supports(['WiredMacAuth', 'WiredDot1x', 'WirelessMacAuth', 'WirelessDot1x'])"
          :column-label="$i18n.t('Disconnect Port')"
          :text="$i18n.t('For Disconnect request, if we have to send to another port.')"
        />

        <form-group-coa-port namespace="coaPort"
          v-show="supports(['WiredMacAuth', 'WiredDot1x', 'WirelessMacAuth', 'WirelessDot1x'])"
          :column-label="$i18n.t('CoA Port')"
          :text="$i18n.t('For CoA request, if we have to send to another port.')"
        />

        <form-group-post-mfa-validation namespace="PostMfaValidation"
          :column-label="$i18n.t('Post MFA Validation')"
          :text="$i18n.t('Add an extra validation in the RADIUS flow to detect if the user successfully validate the MFA.')"
        />

        <form-group-cli-access namespace="cliAccess"
          :column-label="$i18n.t('CLI/VPN Access Enabled')"
          :text="$i18n.t('Allow this network equipment to use PacketFence as a RADIUS server for CLI or VPN access.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('SNMP')">

        <form-group-snmp-use-connector namespace="SNMPUseConnector"
          :column-label="$i18n.t('Use Connector')"
          :text="$i18n.t('Use the available PacketFence connectors to connect to this switch in SNMP. By default, a local connector is hosted on this server.')"
        />

        <form-group-snmp-version namespace="SNMPVersion"
          :column-label="$i18n.t('Version')"
        />

        <form-group-snmp-community-read namespace="SNMPCommunityRead"
          :column-label="$i18n.t('Community Read')"
        />

        <form-group-snmp-community-write namespace="SNMPCommunityWrite"
          :column-label="$i18n.t('Community Write')"
        />

        <form-group-snmp-engine-identifier namespace="SNMPEngineID"
          :column-label="$i18n.t('Engine ID')"
        />

        <form-group-snmp-user-name-read namespace="SNMPUserNameRead"
          :column-label="$i18n.t('User Name Read')"
        />

        <form-group-snmp-auth-protocol-read namespace="SNMPAuthProtocolRead"
          :column-label="$i18n.t('Auth Protocol Read')"
        />

        <form-group-snmp-auth-password-read namespace="SNMPAuthPasswordRead"
          :column-label="$i18n.t('Auth Password Read')"
        />

        <form-group-snmp-priv-protocol-read namespace="SNMPPrivProtocolRead"
          :column-label="$i18n.t('Priv Protocol Read')"
        />

        <form-group-snmp-priv-password-read namespace="SNMPPrivPasswordRead"
          :column-label="$i18n.t('Priv Password Read')"
        />

        <form-group-snmp-user-name-write namespace="SNMPUserNameWrite"
          :column-label="$i18n.t('User Name Write')"
        />

        <form-group-snmp-auth-protocol-write namespace="SNMPAuthProtocolWrite"
          :column-label="$i18n.t('Auth Protocol Write')"
        />

        <form-group-snmp-auth-password-write namespace="SNMPAuthPasswordWrite"
          :column-label="$i18n.t('Auth Password Write')"
        />

        <form-group-snmp-priv-protocol-write namespace="SNMPPrivProtocolWrite"
          :column-label="$i18n.t('Priv Protocol Write')"
        />

        <form-group-snmp-priv-password-write namespace="SNMPPrivPasswordWrite"
          :column-label="$i18n.t('Priv Password Write')"
        />

        <form-group-snmp-version-trap namespace="SNMPVersionTrap"
          :column-label="$i18n.t('Version Trap')"
        />

        <form-group-snmp-community-trap namespace="SNMPCommunityTrap"
          :column-label="$i18n.t('Community Trap')"
        />

        <form-group-snmp-user-name-trap namespace="SNMPUserNameTrap"
          :column-label="$i18n.t('User Name Trap')"
        />

        <form-group-snmp-auth-protocol-trap namespace="SNMPAuthProtocolTrap"
          :column-label="$i18n.t('Auth Protocol Trap')"
        />

        <form-group-snmp-auth-password-trap namespace="SNMPAuthPasswordTrap"
          :column-label="$i18n.t('Auth Password Trap')"
        />

        <form-group-snmp-priv-protocol-trap namespace="SNMPPrivProtocolTrap"
          :column-label="$i18n.t('Priv Protocol Trap')"
        />

        <form-group-snmp-priv-password-trap namespace="SNMPPrivPasswordTrap"
          :column-label="$i18n.t('Priv Password Trap')"
        />

        <form-group-mac-searches-max-nb namespace="macSearchesMaxNb"
          :column-label="$i18n.t('Maximum MAC addresses')"
          :text="$i18n.t('Maximum number of MAC addresses retrived from a port.')"
        />

        <form-group-mac-searches-sleep-interval namespace="macSearchesSleepInterval"
          :column-label="$i18n.t('Sleep interval')"
          :text="$i18n.t('Sleep interval between queries of MAC addresses.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('CLI')">

        <form-group-cli-transport namespace="cliTransport"
          :column-label="$i18n.t('Transport')"
        />
        <form-group-cli-user namespace="cliUser"
          :column-label="$i18n.t('Username')"
        />
        <form-group-cli-pwd namespace="cliPwd"
          :column-label="$i18n.t('Password')"
        />
        <form-group-cli-enable-pwd namespace="cliEnablePwd"
          :column-label="$i18n.t('Enable Password')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Web Services')">

        <form-group-web-services-transport namespace="wsTransport"
          :column-label="$i18n.t('Transport')"
        />
        <form-group-web-services-user namespace="wsUser"
          :column-label="$i18n.t('Username')"
        />
        <form-group-web-services-pwd namespace="wsPwd"
          :column-label="$i18n.t('Password')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('ACLs')" v-if="supports(['PushACLs', 'DownloadableListBasedEnforcement'])">

        <form-group-use-push-acls v-show="supports(['PushACLs'])"
          namespace="UsePushACLs"
          :column-label="$i18n.t('Push ACLs')"
          :text="$i18n.t('Enable ACLs to be pushed directly on the equipment. Only ACLs defined in the global role configuration will be applied. If an ACL is defined in the switch config role section then this one will be pushed via RADIUS if possible')"
        />

        <form-group-container v-show="supports(['PushACLs']) && isUsePushACLs">
          <b-button :disabled="isLoading"
            variant="outline-primary" @click="onPrecreate">Precreate ACLs</b-button>
        </form-group-container>

        <form-group-downloadable-acls-limit v-show="supports(['DownloadableListBasedEnforcement'])"
          namespace="DownloadableACLsLimit"
          :column-label="$i18n.t('Maximum ACLs per switch')"
          :text="$i18n.t('The maximum number of ACLs PacketFence can send to the switch.')"
        />

        <form-group-use-downloadable-acls v-show="supports(['DownloadableListBasedEnforcement'])"
          namespace="UseDownloadableACLs"
          :column-label="$i18n.t('Downloadable ACLs')"
          :text="$i18n.t('Enable Downloadable ACLs through RADIUS instead of Dynamic ACLs.')"
        />

        <form-group-acls-limit namespace="ACLsLimit" v-show="supports(['DownloadableListBasedEnforcement']) && isUseDownloadableACLs"
          :column-label="$i18n.t('Maximum ACLs per RADIUS reply')"
          :text="$i18n.t('The maximum number of ACLs PacketFence can send to the switch in a single RADIUS reply.')"
        />

      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import {
  BaseForm,
  BaseFormTab,

  BaseInputToggleAdvancedMode
} from '@/components/new/'
import {
  FormGroupContainer,
  FormGroupCliAccess,
  FormGroupCliEnablePwd,
  FormGroupCliPwd,
  FormGroupCliTransport,
  FormGroupCliUser,
  FormGroupCoaPort,
  FormGroupControllerIp,
  FormGroupDeauthenticationMethod,
  FormGroupDescription,
  FormGroupDisconnectPort,
  FormGroupExternalPortalEnforcement,
  FormGroupGroup,
  FormGroupIdentifier,
  FormGroupInlineTrigger,
  FormGroupMacSearchesMaxNb,
  FormGroupMacSearchesSleepInterval,
  FormGroupMode,
  FormGroupRadiusDeauthUseConnector,
  FormGroupRadiusSecret,
  FormGroupRoleMapAccessList,
  FormGroupRoleMapRole,
  FormGroupRoleMapVpn,
  FormGroupRoleMapUrl,
  FormGroupRoleMapVlan,
  FormGroupRoleMapInterface,
  FormGroupSnmpAuthProtocolTrap,
  FormGroupSnmpAuthPasswordTrap,
  FormGroupSnmpCommunityRead,
  FormGroupSnmpCommunityTrap,
  FormGroupSnmpCommunityWrite,
  FormGroupSnmpAuthPasswordRead,
  FormGroupSnmpAuthProtocolRead,
  FormGroupSnmpAuthProtocolWrite,
  FormGroupSnmpAuthPasswordWrite,
  FormGroupSnmpEngineIdentifier,
  FormGroupSnmpPrivPasswordRead,
  FormGroupSnmpPrivPasswordTrap,
  FormGroupSnmpPrivPasswordWrite,
  FormGroupSnmpPrivProtocolRead,
  FormGroupSnmpPrivProtocolTrap,
  FormGroupSnmpPrivProtocolWrite,
  FormGroupSnmpUseConnector,
  FormGroupSnmpUserNameTrap,
  FormGroupSnmpUserNameWrite,
  FormGroupSnmpUserNameRead,
  FormGroupSnmpVersion,
  FormGroupSnmpVersionTrap,
  FormGroupToggleAccessListMap,
  FormGroupToggleRoleMap,
  FormGroupToggleVpnMap,
  FormGroupToggleUrlMap,
  FormGroupToggleVlanMap,
  FormGroupToggleNetworkMap,
  FormGroupToggleInterfaceMap,
  FormGroupType,
  FormGroupUplink,
  FormGroupUplinkDynamic,
  FormGroupUseCoa,
  FormGroupUsePushAcls,
  FormGroupUseDownloadableAcls,
  FormGroupDownloadableAclsLimit,
  FormGroupAclsLimit,
  FormGroupDeauthOnPrevious,
  FormGroupVoipEnabled,
  FormGroupVoipLldpDetect,
  FormGroupVoipCdpDetect,
  FormGroupVoipDhcpDetect,
  FormGroupPostMfaValidation,
  FormGroupWebServicesPwd,
  FormGroupWebServicesTransport,
  FormGroupWebServicesUser,

  InputRoleMapNetwork,
  InputToggleNetworkFrom,
} from './'

const components = {
  BaseForm,
  BaseFormTab,
  BaseInputToggleAdvancedMode,

  FormGroupContainer,
  FormGroupCliAccess,
  FormGroupCliEnablePwd,
  FormGroupCliPwd,
  FormGroupCliTransport,
  FormGroupCliUser,
  FormGroupCoaPort,
  FormGroupControllerIp,
  FormGroupDeauthenticationMethod,
  FormGroupDescription,
  FormGroupDisconnectPort,
  FormGroupExternalPortalEnforcement,
  FormGroupGroup,
  FormGroupIdentifier,
  FormGroupInlineTrigger,
  FormGroupMacSearchesMaxNb,
  FormGroupMacSearchesSleepInterval,
  FormGroupMode,
  FormGroupRadiusDeauthUseConnector,
  FormGroupRadiusSecret,
  FormGroupRoleMapAccessList,
  FormGroupRoleMapRole,
  FormGroupRoleMapVpn,
  FormGroupRoleMapUrl,
  FormGroupRoleMapVlan,
  FormGroupRoleMapInterface,
  FormGroupSnmpAuthProtocolTrap,
  FormGroupSnmpAuthPasswordTrap,
  FormGroupSnmpCommunityRead,
  FormGroupSnmpCommunityTrap,
  FormGroupSnmpCommunityWrite,
  FormGroupSnmpAuthPasswordRead,
  FormGroupSnmpAuthProtocolRead,
  FormGroupSnmpAuthProtocolWrite,
  FormGroupSnmpAuthPasswordWrite,
  FormGroupSnmpEngineIdentifier,
  FormGroupSnmpPrivPasswordRead,
  FormGroupSnmpPrivPasswordTrap,
  FormGroupSnmpPrivPasswordWrite,
  FormGroupSnmpPrivProtocolRead,
  FormGroupSnmpPrivProtocolTrap,
  FormGroupSnmpPrivProtocolWrite,
  FormGroupSnmpUseConnector,
  FormGroupSnmpUserNameTrap,
  FormGroupSnmpUserNameWrite,
  FormGroupSnmpUserNameRead,
  FormGroupSnmpVersion,
  FormGroupSnmpVersionTrap,
  FormGroupToggleAccessListMap,
  FormGroupToggleRoleMap,
  FormGroupToggleVpnMap,
  FormGroupToggleUrlMap,
  FormGroupToggleVlanMap,
  FormGroupToggleNetworkMap,
  FormGroupToggleInterfaceMap,
  FormGroupType,
  FormGroupUplink,
  FormGroupUplinkDynamic,
  FormGroupUseCoa,
  FormGroupUsePushAcls,
  FormGroupUseDownloadableAcls,
  FormGroupAclsLimit,
  FormGroupDownloadableAclsLimit,
  FormGroupDeauthOnPrevious,
  FormGroupVoipEnabled,
  FormGroupVoipLldpDetect,
  FormGroupVoipCdpDetect,
  FormGroupVoipDhcpDetect,
  FormGroupPostMfaValidation,
  FormGroupWebServicesPwd,
  FormGroupWebServicesTransport,
  FormGroupWebServicesUser,

  InputRoleMapNetwork,
  InputToggleNetworkFrom,
}

import { useForm, useFormProps as props } from '../_composables/useForm'

export const setup = (props, context) => useForm(props, context)

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
