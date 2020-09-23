<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('General')" class="pt-3 px-3" active>

        <form-group-identifier namespace="id"
          :column-label="$i18n.t('Realm')"
          :disabled="!isNew && !isClone"
        />

        <form-group-regex namespace="regex"
          :column-label="$i18n.t('Regex Realm')"
          :text="$i18n.t('PacketFence will use this Realm configuration if the regex match with the UserName (optional).')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('NTLM Auth')" class="pt-3 px-3">

        <form-group-domain namespace="domain"
          :column-label="$i18n.t('Domain')"
          :text="$i18n.t('The domain to use for the authentication in that realm.')"
        />

        <form-group-edir-source namespace="edir_source"
          :column-label="$i18n.t('eDirectory')"
          :text="$i18n.t('The eDirectory server to use for the authentication in that realm.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('EAP Configuration')" class="pt-3 px-3">

        <form-group-eap namespace="eap"
          :column-label="$i18n.t('EAP')"
          :text="$i18n.t('The EAP configuration to use.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Freeradius Proxy')" class="pt-3 px-3">

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

        <form-group-radius-acct-chosen namespace="radius_acct_chosen"
          :column-label="$i18n.t('RADIUS ACCT')"
          :text="$i18n.t('The RADIUS Server(s) to proxy accounting.')"
        />

        <form-group-radius-acct-proxy-type namespace="radius_acct_proxy_type"
          :column-label="$i18n.t('Type')"
          :text="$i18n.t('Home server pool type.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Freeradius Eduroam Proxy')" class="pt-3 px-3">

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

        <form-group-eduroam-radius-acct-chosen namespace="eduroam_radius_acct_chosen"
          :column-label="$i18n.t('Eduroam RADIUS ACCT')"
          :text="$i18n.t('The RADIUS Server(s) to proxy accounting.')"
        />

        <form-group-eduroam-radius-acct-proxy-type namespace="eduroam_radius_acct_proxy_type"
          :column-label="$i18n.t('Type')"
          :text="$i18n.t('Home server pool type.')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Stripping')" class="pt-3 px-3">

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
    </b-tabs>
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm,
  BaseFormTab
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupIdentifier,
  FormGroupRegex,
  FormGroupDomain,
  FormGroupEdirSource,
  FormGroupEap,
  FormGroupOptions,
  FormGroupRadiusAuth,
  FormGroupRadiusAuthProxyType,
  FormGroupRadiusAuthComputeInPf,
  FormGroupRadiusAcctChosen,
  FormGroupRadiusAcctProxyType,
  FormGroupEduroamOptions,
  FormGroupEduroamRadiusAuth,
  FormGroupEduroamRadiusAuthProxyType,
  FormGroupEduroamRadiusAuthComputeInPf,
  FormGroupEduroamRadiusAcctChosen,
  FormGroupEduroamRadiusAcctProxyType,
  FormGroupPortalStripUsername,
  FormGroupAdminStripUsername,
  FormGroupRadiusStripUsername,
  FormGroupPermitCustomAttributes,
  FormGroupLdapSource,
  FormGroupLdapSourceTtlsPap
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupRegex,
  FormGroupDomain,
  FormGroupEdirSource,
  FormGroupEap,
  FormGroupOptions,
  FormGroupRadiusAuth,
  FormGroupRadiusAuthProxyType,
  FormGroupRadiusAuthComputeInPf,
  FormGroupRadiusAcctChosen,
  FormGroupRadiusAcctProxyType,
  FormGroupEduroamOptions,
  FormGroupEduroamRadiusAuth,
  FormGroupEduroamRadiusAuthProxyType,
  FormGroupEduroamRadiusAuthComputeInPf,
  FormGroupEduroamRadiusAcctChosen,
  FormGroupEduroamRadiusAcctProxyType,
  FormGroupPortalStripUsername,
  FormGroupAdminStripUsername,
  FormGroupRadiusStripUsername,
  FormGroupPermitCustomAttributes,
  FormGroupLdapSource,
  FormGroupLdapSourceTtlsPap
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
  const schema = computed(() => schemaFn(props))

  return {
    schema
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

