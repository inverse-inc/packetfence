<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <template v-slot:tabs-end>
        <div class="text-right mr-3">
          <base-input-toggle-advanced-mode v-model="advancedMode"/>
        </div>
      </template>

      <base-form-tab :title="$i18n.t('Definition')" active>

        <form-group-identifier namespace="id"
          :column-label="$i18n.t('IP Address/MAC Address/Range (CIDR)')"
        />

        <form-group-identifier namespace="description"
          :column-label="$i18n.t('Description')"
        />

        <form-group-tenant-identifier namespace="TenantId"
          :column-label="$i18n.t('Tenant')"
          :text="$i18n.t('The tenant associated to this switch entry. Single tenant deployments should never have to modify this value.')"
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

        <form-group-use-coa namespace="useCoA"
          :column-label="$i18n.t('Use CoA')"
          :text="$i18n.t('Use CoA when available to deauthenticate the user. When disabled, RADIUS Disconnect will be used instead if it is available.')"
        />

        <form-group-cli-access namespace="cliAccess"
          :column-label="$i18n.t('CLI Access Enabled')"
          :text="$i18n.t('Allow this switch to use PacketFence as a RADIUS server for CLI access.')"
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

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Roles')">

        <div v-if="!advancedMode && !form.type"
          class="alert alert-warning"
        >
          <strong>{{ $i18n.t('Note:') }}</strong>
          {{ $i18n.t('Choose a Switch type, or enable advanced mode to manage roles.') }}
        </div>

        <template v-else>
          <b-card v-show="supports(['RadiusDynamicVlanAssignment'])"
            class="mb-3 pb-0" no-body
          >
            <b-card-header>
              <h4 class="mb-0" v-t="'Role mapping by VLAN ID'"></h4>
            </b-card-header>
            <div class="card-body pb-0">
              <form-group-toggle-vlan-map namespace="VlanMap"
                :column-label="$i18n.t('Role by VLAN ID')"
              />

              <form-group-role-map-vlan v-for="role in roles" :key="`${role}Vlan`" :namespace="`${role}Vlan`"
                v-show="isVlanMap"
                :column-label="role"
              />
            </div>
          </b-card>

          <b-card v-show="supports(['RoleBasedEnforcement'])"
            class="mb-3 pb-0" no-body
          >
            <b-card-header>
              <h4 class="mb-0" v-t="'Role mapping by Switch Role'"></h4>
            </b-card-header>
            <div class="card-body pb-0">
              <form-group-toggle-role-map namespace="RoleMap"
                :column-label="$i18n.t('Role by Switch Role')"
              />

              <form-group-role-map-role v-for="role in roles" :key="`${role}Role`" :namespace="`${role}Role`"
                v-show="isRoleMap"
                :column-label="role"
              />
            </div>
          </b-card>

          <b-card v-show="supports(['AccessListBasedEnforcement'])"
            class="mb-3 pb-0" no-body
          >
            <b-card-header>
              <h4 class="mb-0" v-t="'Role mapping by Access List'"></h4>
            </b-card-header>
            <div class="card-body pb-0">
              <form-group-toggle-access-list-map namespace="AccessListMap"
                :column-label="$i18n.t('Role by Access List')"
              />

              <form-group-role-map-access-list v-for="role in roles" :key="`${role}AccessList`" :namespace="`${role}AccessList`"
                v-show="isAccessListMap"
                :column-label="role"
              />
            </div>
          </b-card>

          <b-card v-show="supports(['ExternalPortal'])"
            class="mb-3 pb-0" no-body
          >
            <b-card-header>
              <h4 class="mb-0" v-t="'Role mapping by Web Auth URL'"></h4>
            </b-card-header>
            <div class="card-body pb-0">
              <form-group-toggle-url-map namespace="UrlMap"
                :column-label="$i18n.t('Role by Web Auth URL')"
              />

              <form-group-role-map-url v-for="role in roles" :key="`${role}Url`" :namespace="`${role}Url`"
                v-show="isUrlMap"
                :column-label="role"
              />
            </div>
          </b-card>

        </template>
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

      </base-form-tab>
      <base-form-tab :title="$i18n.t('SNMP')">

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
      <base-form-tab :title="$i18n.t('Members')" v-if="!isNew && !isClone">

        <b-card no-body class="mb-3">
          <b-card-header>
            <h4 class="mb-0" v-t="'Current Members'"></h4>
          </b-card-header>
          <div class="card-body pb-0">
            <b-table
              :items="members"
              :fields="memberFields"
              :sort-by="memberSortBy"
              :sort-desc="memberSortDesc"
              show-empty
              responsive
              sort-icon-left
              fixed
              class="mb-0"
            >
              <template v-slot:empty>
                <b-container class="my-5">
                    <b-row class="justify-content-md-center text-secondary">
                        <b-col cols="12" md="auto">
                            <icon v-if="memberIsLoading" name="circle-notch" scale="1.5" spin></icon>
                            <b-media v-else>
                                <template v-slot:aside><icon name="search" scale="2"></icon></template>
                                <h4>{{ $t('No switch group members found') }}</h4>
                                <p class="font-weight-light">{{ $t('Click the button below to add a new member.') }}</p>
                            </b-media>
                        </b-col>
                    </b-row>
                </b-container>
              </template>
              <template v-slot:cell(id)="{ item, value }">
                <b-button variant="link" :to="{ name: 'switch', params: { id: item.id } }">{{ value }}</b-button>
              </template>
              <template v-slot:cell(buttons)="{ item }">
                <base-button-delete v-if="id !== 'default'"
                  class="mr-1" size="sm" variant="outline-danger"
                  :disabled="memberIsLoading"
                  :confirm="$t('Delete Member?')"
                  @delete="removeMember(item)"
                  reverse
                />
              </template>
            </b-table>
          </div>
        </b-card>

        <b-card no-body class="mb-3">
          <b-card-header>
            <h4 class="mb-0" v-t="'New Member'"></h4>
          </b-card-header>
          <b-input-group class="card-body text-nowrap">
            <base-input-chosen-one
              v-model="memberIdentifier"
              :placeholder="$t('Type to search')"
              :options="filteredSwitches"
              :disabled="memberIsLoading"
            />

            <b-button :disabled="!memberIdentifier || memberIsLoading"
              variant="outline-primary" class="ml-2"
              @click="addMember()"
            >{{ $t('Add New Member') }}</b-button>
          </b-input-group>
        </b-card>

      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import {
  BaseButtonDelete,
  BaseForm,
  BaseFormTab,

  BaseInputChosenOne,
  BaseInputToggleAdvancedMode
} from '@/components/new/'
import {
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
  FormGroupRadiusSecret,
  FormGroupRoleMapAccessList,
  FormGroupRoleMapRole,
  FormGroupRoleMapUrl,
  FormGroupRoleMapVlan,
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
  FormGroupSnmpUserNameTrap,
  FormGroupSnmpUserNameWrite,
  FormGroupSnmpUserNameRead,
  FormGroupSnmpVersion,
  FormGroupSnmpVersionTrap,
  FormGroupTenantIdentifier,
  FormGroupToggleAccessListMap,
  FormGroupToggleRoleMap,
  FormGroupToggleUrlMap,
  FormGroupToggleVlanMap,
  FormGroupType,
  FormGroupUplink,
  FormGroupUplinkDynamic,
  FormGroupUseCoa,
  FormGroupVoipEnabled,
  FormGroupVoipLldpDetect,
  FormGroupVoipCdpDetect,
  FormGroupVoipDhcpDetect,
  FormGroupWebServicesPwd,
  FormGroupWebServicesTransport,
  FormGroupWebServicesUser,
} from './'

const components = {
  BaseButtonDelete,
  BaseForm,
  BaseFormTab,
  BaseInputChosenOne,
  BaseInputToggleAdvancedMode,

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
  FormGroupRadiusSecret,
  FormGroupRoleMapAccessList,
  FormGroupRoleMapRole,
  FormGroupRoleMapUrl,
  FormGroupRoleMapVlan,
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
  FormGroupSnmpUserNameTrap,
  FormGroupSnmpUserNameWrite,
  FormGroupSnmpUserNameRead,
  FormGroupSnmpVersion,
  FormGroupSnmpVersionTrap,
  FormGroupTenantIdentifier,
  FormGroupToggleAccessListMap,
  FormGroupToggleRoleMap,
  FormGroupToggleUrlMap,
  FormGroupToggleVlanMap,
  FormGroupType,
  FormGroupUplink,
  FormGroupUplinkDynamic,
  FormGroupUseCoa,
  FormGroupVoipEnabled,
  FormGroupVoipLldpDetect,
  FormGroupVoipCdpDetect,
  FormGroupVoipDhcpDetect,
  FormGroupWebServicesPwd,
  FormGroupWebServicesTransport,
  FormGroupWebServicesUser,
}

import { useForm as useSwitchForm, useFormProps as props } from '../../switches/_composables/useForm'
import { useForm as useSwitchGroupForm } from '../_composables/useForm'

export const setup = (props, context) => {

  const switchFormProps = useSwitchForm(props, context)
  const switchGroupFormProps = useSwitchGroupForm(props, context)

  return {
    ...switchFormProps,
    ...switchGroupFormProps
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
