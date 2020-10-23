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
roles
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Inline')">
inline
      </base-form-tab>
      <base-form-tab :title="$i18n.t('RADIUS')" v-if="supports(['WiredMacAuth', 'WiredDot1x', 'WirelessMacAuth', 'WirelessDot1x', 'VPN'])">
radius
      </base-form-tab>
      <base-form-tab :title="$i18n.t('SNMP')">
snmp
      </base-form-tab>
      <base-form-tab :title="$i18n.t('CLI')">
cli
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Web Services')">
web services
      </base-form-tab>

<!--

      <base-form-tab :title="$i18n.t('General')" active>

        <form-group-identifier namespace="id"
          :column-label="$i18n.t('Realm')"
          :disabled="!isNew && !isClone"
        />

        <form-group-regex namespace="regex"
          :column-label="$i18n.t('Regex Realm')"
          :text="$i18n.t('PacketFence will use this Realm configuration if the regex match with the UserName (optional).')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('NTLM Auth')">

        <form-group-domain namespace="domain"
          :column-label="$i18n.t('Domain')"
          :text="$i18n.t('The domain to use for the authentication in that realm.')"
        />

        <form-group-edir-source namespace="edir_source"
          :column-label="$i18n.t('eDirectory')"
          :text="$i18n.t('The eDirectory server to use for the authentication in that realm.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('EAP Configuration')">

        <form-group-eap namespace="eap"
          :column-label="$i18n.t('EAP')"
          :text="$i18n.t('The EAP configuration to use.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Freeradius Proxy')">

        <form-group-options namespace="options"
          :column-label="$i18n.t('Realm Options')"
          :text="$i18n.t('You can add FreeRADIUS options in the realm definition.')"
        />

        <form-group-radius-auth namespace="radius_auth"
          :column-label="$i18n.t('RADIUS AUTH')"
          :text="$i18n.t('The RADIUS Server(s) to proxy authentication.')"
        />

        <form-group-radius-auth-proxy-type namespace="radius_auth_proxy_type"
          :column-label="$i18n.t('Type')"
          :text="$i18n.t('Home server pool type.')"
        />

        <form-group-radius-auth-compute-in-pf namespace="radius_auth_compute_in_pf"
          :column-label="$i18n.t('Authorize from PacketFence')"
          :text="$i18n.t('Should we forward the request to PacketFence to have a dynamic answer or do we use the remote proxy server answered attributes?')"
        />

        <form-group-radius-acct namespace="radius_acct"
          :column-label="$i18n.t('RADIUS ACCT')"
          :text="$i18n.t('The RADIUS Server(s) to proxy accounting.')"
        />

        <form-group-radius-acct-proxy-type namespace="radius_acct_proxy_type"
          :column-label="$i18n.t('Type')"
          :text="$i18n.t('Home server pool type.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Freeradius Eduroam Proxy')">

        <form-group-eduroam-options namespace="eduroam_options"
          :column-label="$i18n.t('Eduroam Realm Options')"
          :text="$i18n.t('You can add Eduroam FreeRADIUS options in the realm definition.')"
        />

        <form-group-eduroam-radius-auth namespace="eduroam_radius_auth"
          :column-label="$i18n.t('Eduroam RADIUS AUTH')"
          :text="$i18n.t('The RADIUS Server(s) to proxy authentication.')"
        />

        <form-group-eduroam-radius-auth-proxy-type namespace="eduroam_radius_auth_proxy_type"
          :column-label="$i18n.t('Type')"
          :text="$i18n.t('Home server pool type.')"
        />

        <form-group-eduroam-radius-auth-compute-in-pf namespace="eduroam_radius_auth_compute_in_pf"
          :column-label="$i18n.t('Authorize from PacketFence')"
          :text="$i18n.t('Should we forward the request to PacketFence to have a dynamic answer or do we use the remote proxy server answered attributes?')"
        />

        <form-group-eduroam-radius-acct namespace="eduroam_radius_acct"
          :column-label="$i18n.t('Eduroam RADIUS ACCT')"
          :text="$i18n.t('The RADIUS Server(s) to proxy accounting.')"
        />

        <form-group-eduroam-radius-acct-proxy-type namespace="eduroam_radius_acct_proxy_type"
          :column-label="$i18n.t('Type')"
          :text="$i18n.t('Home server pool type.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Stripping')">

        <form-group-portal-strip-username namespace="portal_strip_username"
          :column-label="$i18n.t('Strip on the portal')"
          :text="$i18n.t('Should the usernames matching this realm be stripped when used on the captive portal.')"
        />

        <form-group-admin-strip-username namespace="admin_strip_username"
          :column-label="$i18n.t('Strip on the admin')"
          :text="$i18n.t('Should the usernames matching this realm be stripped when used on the administration interface.')"
        />

        <form-group-radius-strip-username namespace="radius_strip_username"
          :column-label="$i18n.t('Strip in RADIUS authorization')"
          :text="$i18n.t(`Should the usernames matching this realm be stripped when used in the authorization phase of 802.1x.\nNote that this doesn't control the stripping in FreeRADIUS, use the options above for that.`)"
        />

        <form-group-permit-custom-attributes namespace="permit_custom_attributes"
          :column-label="$i18n.t('Custom attributes')"
          :text="$i18n.t('Allow to use custom attributes to authenticate 802.1x users (attributes are defined in the source).')"
        />

        <form-group-ldap-source namespace="ldap_source"
          :column-label="$i18n.t('LDAP source')"
          :text="$i18n.t('The LDAP Server to query the custom attributes.')"
        />

        <form-group-ldap-source-ttls-pap namespace="ldap_source_ttls_pap"
          :column-label="$i18n.t('LDAP Source for TTLS PAP')"
          :text="$i18n.t('The LDAP Server to use for EAP TTLS PAP authorization and authentication.')"
        />

      </base-form-tab>
-->
    </b-tabs>
  </base-form>
</template>
<script>
import { computed, ref, toRefs, unref } from '@vue/composition-api'
import {
  BaseForm,
  BaseFormTab,

  BaseInputToggleAdvancedMode
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupCliAccess,
  FormGroupCoaPort,
  FormGroupControllerIp,
  FormGroupDeauthenticationMethod,
  FormGroupDescription,
  FormGroupDisconnectPort,
  FormGroupExternalPortalEnforcement,
  FormGroupGroup,
  FormGroupIdentifier,
  FormGroupMode,
  FormGroupTenantIdentifier,
  FormGroupType,
  FormGroupUplink,
  FormGroupUplinkDynamic,
  FormGroupUseCoa,
  FormGroupVoipEnabled,
  FormGroupVoipLldpDetect,
  FormGroupVoipCdpDetect,
  FormGroupVoipDhcpDetect,
} from './'

const components = {
  BaseForm,
  BaseFormTab,
  BaseInputToggleAdvancedMode,

  FormGroupCliAccess,
  FormGroupCoaPort,
  FormGroupControllerIp,
  FormGroupDeauthenticationMethod,
  FormGroupDescription,
  FormGroupDisconnectPort,
  FormGroupExternalPortalEnforcement,
  FormGroupGroup,
  FormGroupIdentifier,
  FormGroupMode,
  FormGroupTenantIdentifier,
  FormGroupType,
  FormGroupUplink,
  FormGroupUplinkDynamic,
  FormGroupUseCoa,
  FormGroupVoipEnabled,
  FormGroupVoipLldpDetect,
  FormGroupVoipCdpDetect,
  FormGroupVoipDhcpDetect,
}

export const props = {
  id: {
    type: String
  },
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props) => {

  const {
    form,
    meta
  } = toRefs(props)

  const advancedMode = ref(false)
  const schema = computed(() => schemaFn(props))

  const switchGroup = computed(() => {
    const { group } = unref(form)
    return group
  })

  const supported = computed(() => {
    const { type } = form.value
    const { type: { allowed = [] } = {} } = meta.value
    return allowed.reduce((_supports, group) => {
      const { options = [] } = group
      for (let i = 0; i < options.length; i++) {
        const { [i]: { value, supports = [] } = {} } = options
        if (value === type)
          _supports = supports
      }
      return _supports
    }, [])
  })

  const supports = (allowed) => {
    if (advancedMode.value)
      return true
    for (let i = 0; i < allowed.length; i++) {
      if (supported.value.includes(allowed[i]))
        return true
    }
    return false
  }

  const isUplinkDynamic = computed(() => {
    // inspect form value for `uplink_dynamic`
    const { uplink_dynamic } = form.value
    if (uplink_dynamic !== null)
      return uplink_dynamic === 'dynamic'

    // inspect meta placeholder for `uplink_dynamic`
    const { uplink_dynamic: { placeholder } = {} } =  meta.value
    return placeholder === 'dynamic'
  })

  return {
    advancedMode,
    schema,
    switchGroup,

    supports,
    isUplinkDynamic
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

