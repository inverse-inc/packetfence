<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs>
      <base-form-tab :title="$i18n.t('Settings')" active>
        <form-group-identifier namespace="id"
          :column-label="$i18n.t('Profile Name')"
          :text="$i18n.t('A profile id can only contain alphanumeric characters, dashes, period and or underscores.')"
          :disabled="!isNew && !isClone"
        />

        <form-group-description namespace="description"
          :column-label="$i18n.t('Profile Description')"
        />

        <form-group-status v-show="!isDefault"
          namespace="status"
          :column-label="$i18n.t('Enable profile')"
        />

        <form-group-root-module namespace="root_module"
          :column-label="$i18n.t('Root Portal Module')"
          :text="$i18n.t('The Root Portal Module to use.')"
        />

        <form-group-preregistration namespace="preregistration"
          :column-label="$i18n.t('Activate preregistration')"
          :text="$i18n.t(`This activates preregistration on the connection profile. Meaning, instead of applying the access to the currently connected device, it displays a local account that is created while registering. Note that activating this disables the on-site registration on this connection profile. Also, make sure the sources on the connection profile have 'Create local account' enabled.`)"
        />

        <form-group-autoregister namespace="autoregister"
          :column-label="$i18n.t('Automatically register devices')"
          :text="$i18n.t('This activates automatic registation of devices for the profile. Devices will not be shown a captive portal and RADIUS authentication credentials will be used to register the device. This option only makes sense in the context of an 802.1x authentication.')"
        />

        <form-group-reuse-dot1x-credentials namespace="reuse_dot1x_credentials"
          :column-label="$i18n.t('Reuse dot1x credentials')"
          :text="$i18n.t('This option emulates SSO when someone needs to face the captive portal after a successful 802.1x connection. 802.1x credentials are reused on the portal to match an authentication and get the appropriate actions. As a security precaution, this option will only reuse 802.1x credentials if there is an authentication source matching the provided realm. This means, if users use 802.1x credentials with a domain part (username@domain, domain\\username), the domain part needs to be configured as a realm under the RADIUS section and an authentication source needs to be configured for that realm. If users do not use 802.1x credentials with a domain part, only the NULL realm will be match IF an authentication source is configured for it.')"
        />

        <form-group-dot1x-recompute-role-from-portal namespace="dot1x_recompute_role_from_portal"
          :column-label="$i18n.t('Dot1x recompute role from portal')"
          :text="$i18n.t('When enabled, PacketFence will not use the role initialy computed on the portal but will use the dot1x username to recompute the role.')"
        />

        <form-group-mac-auth-recompute-role-from-portal namespace="mac_auth_recompute_role_from_portal"
          :column-label="$i18n.t('MAC Auth recompute role from portal')"
          :text="$i18n.t('When enabled, PacketFence will not use the role initialy computed on the portal but will use an authorized source if defined to recompute the role.')"
        />

        <form-group-dot1x-unset-on-unmatch namespace="dot1x_unset_on_unmatch"
          :column-label="$i18n.t('Dot1x unset on unmatch')"
          :text="$i18n.t('When enabled, PacketFence will unset the role of the device if no authentication sources returned one.')"
        />

        <form-group-dpsk namespace="dpsk"
          :column-label="$i18n.t('Enable DPSK')"
          :text="$i18n.t('This enables the Dynamic PSK feature on this connection profile. It means that the RADIUS server will answer requests with specific attributes like the PSK key to use to connect on the SSID')"
        />

        <form-group-default-psk-key namespace="default_psk_key"
          :column-label="$i18n.t('Default PSK key')"
          :text="$i18n.t('This is the default PSK key when you enable DPSK on this connection profile. The minimum length is eight characters.')"
        />

        <form-group-unbound-dpsk namespace="unbound_dpsk"
          :column-label="$i18n.t('Enable Unbound DPSK')"
          :text="$i18n.t('This enable Dynamic Unbound PSK. If the network equipment supports sending attributes that allow to identify the PSK using the Access-Request attributes, then the user attached to the PSK can be found and used in the same manner as in 802.1x.')"
        />

        <form-group-unreg-on-acct-stop namespace="unreg_on_acct_stop"
          :column-label="$i18n.t('Automatically deregister devices on accounting stop')"
          :text="$i18n.t('This activates automatic deregistation of devices for the profile if PacketFence receives a RADIUS accounting stop. This option only makes sense in the context of an 802.1x authentication.')"
        />

        <form-group-vlan-pool-technique namespace="vlan_pool_technique"
          :column-label="$i18n.t('VLAN pool technique')"
          :text="$i18n.t('The algorithm used to calculate the VLAN in a VLAN pool.')"
        />

        <form-group-filter-match-style v-show="!isDefault"
          namespace="filter_match_style"
          :column-label="$i18n.t('Filters')"
        />

        <form-group-filter v-show="!isDefault"
          namespace="filter"
          :column-label="$i18n.t('Filter')"
          :text="$i18n.t('With no filter specified, an advanced filter must be specified')"
        />

        <form-group-advanced-filter v-show="!isDefault"
          namespace="advanced_filter"
          :column-label="$i18n.t('Advanced filter')"
        />

        <form-group-sources namespace="sources"
          :column-label="$i18n.t('Sources')"
          :text="$i18n.t('With no source specified, all internal and external sources will be used.')"
        />

        <form-group-billing-tiers namespace="billing_tiers"
          :column-label="$i18n.t('Billing Tiers')"
          :text="$i18n.t('With no billing tiers specified, all billing tiers will be used.')"
        />

        <form-group-provisioners namespace="provisioners"
          :column-label="$i18n.t('Provisioners')"
          :text="$i18n.t('With no provisioners specified, the provisioners of the default profile will be used.')"
        />

        <form-group-scans namespace="scans"
          :column-label="$i18n.t('Scanners')"
          :text="$i18n.t('With no scan specified, the scan engine will not be triggered.')"
        />

        <form-group-self-service namespace="self_service"
          :column-label="$i18n.t('Self service policy')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Captive Portal')">
        <form-group-logo namespace="logo"
          :column-label="$i18n.t('Logo')"
        />

        <form-group-redirect-url namespace="redirecturl"
          :column-label="$i18n.t('Redirection URL')"
          :text="$i18n.t('Default URL to redirect to on registration/mitigation release. This is only used if a per-security event redirect URL is not defined.')"
        />

        <form-group-always-use-redirecturl namespace="always_use_redirecturl"
          :column-label="$i18n.t('Force redirection URL')"
          :text="$i18n.t('Under most circumstances we can redirect the user to the URL he originally intended to visit. However, you may prefer to force the captive portal to redirect the user to the redirection URL.')"
        />

        <form-group-block-interval namespace="block_interval"
          :column-label="$i18n.t('Block Interval')"
          :text="$i18n.t('The amount of time a user is blocked after reaching the defined limit for login, sms request and sms pin retry.')"
        />

        <form-group-sms-pin-retry-limit namespace="sms_pin_retry_limit"
          :column-label="$i18n.t('SMS Pin Retry Limit')"
          :text="$i18n.t('Maximum number of times a user can retry a SMS PIN before having to request another PIN. A value of 0 disables the limit.')"
        />

        <form-group-sms-request-limit namespace="sms_request_limit"
          :column-label="$i18n.t('SMS Request Retry Limit')"
          :text="$i18n.t('Maximum number of times a user can request a SMS PIN. A value of 0 disables the limit')"
        />

        <form-group-login-attempt-limit namespace="login_attempt_limit"
          :column-label="$i18n.t('Login Attempt Limit')"
          :text="$i18n.t('Limit the number of login attempts. A value of 0 disables the limit.')"
        />

        <form-group-access-registration-when-registered namespace="access_registration_when_registered"
          :column-label="$i18n.t('Allow access to registration portal when registered')"
          :text="$i18n.t('This allows already registered users to be able to re-register their device by first accessing the status page and then accessing the portal. This is useful to allow users to extend their access even though they are already registered.')"
        />

        <form-group-network-logoff namespace="network_logoff"
          :column-label="$i18n.t('Network Logoff')"
          :text="$i18n.t('This allows users to access the network logoff page (http://{fqdn}/networklogoff) in order to terminate their network access (switch their device back to unregistered).', basesGeneral)"
        />

        <form-group-network-logoff-popup namespace="network_logoff_popup"
          :column-label="$i18n.t('Network Logoff Popup')"
          :text="$i18n.t(`When the 'Network Logoff' feature is enabled, this will have it opened in a popup at the end of the registration process.`)"
        />

        <form-group-locale namespace="locale"
          :column-label="$i18n.t('Languages')"
          :text="$i18n.t('With no language specified, all supported locales will be available')"
        />
      </base-form-tab>
      <base-form-tab v-if="!isClone && !isNew"
        :title="$i18n.t('Files')">
        <the-files-list
          :id="id"
        />
      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import {
  BaseForm,
  BaseFormTab
} from '@/components/new/'
import {
  TheFilesList,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupStatus,
  FormGroupRootModule,
  FormGroupPreregistration,
  FormGroupAutoregister,
  FormGroupReuseDot1xCredentials,
  FormGroupDot1xRecomputeRoleFromPortal,
  FormGroupMacAuthRecomputeRoleFromPortal,
  FormGroupDot1xUnsetOnUnmatch,
  FormGroupDpsk,
  FormGroupDefaultPskKey,
  FormGroupUnboundDpsk,
  FormGroupUnregOnAcctStop,
  FormGroupVlanPoolTechnique,
  FormGroupFilterMatchStyle,
  FormGroupFilter,
  FormGroupAdvancedFilter,
  FormGroupSources,
  FormGroupBillingTiers,
  FormGroupProvisioners,
  FormGroupScans,
  FormGroupSelfService,
  FormGroupLogo,
  FormGroupRedirectUrl,
  FormGroupAlwaysUseRedirecturl,
  FormGroupBlockInterval,
  FormGroupSmsPinRetryLimit,
  FormGroupSmsRequestLimit,
  FormGroupLoginAttemptLimit,
  FormGroupAccessRegistrationWhenRegistered,
  FormGroupNetworkLogoff,
  FormGroupNetworkLogoffPopup,
  FormGroupLocale
} from './'

const components = {
  BaseForm,
  BaseFormTab,
  TheFilesList,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupStatus,
  FormGroupRootModule,
  FormGroupPreregistration,
  FormGroupAutoregister,
  FormGroupReuseDot1xCredentials,
  FormGroupDot1xRecomputeRoleFromPortal,
  FormGroupMacAuthRecomputeRoleFromPortal,
  FormGroupDot1xUnsetOnUnmatch,
  FormGroupDpsk,
  FormGroupDefaultPskKey,
  FormGroupUnboundDpsk,
  FormGroupUnregOnAcctStop,
  FormGroupVlanPoolTechnique,
  FormGroupFilterMatchStyle,
  FormGroupFilter,
  FormGroupAdvancedFilter,
  FormGroupSources,
  FormGroupBillingTiers,
  FormGroupProvisioners,
  FormGroupScans,
  FormGroupSelfService,
  FormGroupLogo,
  FormGroupRedirectUrl,
  FormGroupAlwaysUseRedirecturl,
  FormGroupBlockInterval,
  FormGroupSmsPinRetryLimit,
  FormGroupSmsRequestLimit,
  FormGroupLoginAttemptLimit,
  FormGroupAccessRegistrationWhenRegistered,
  FormGroupNetworkLogoff,
  FormGroupNetworkLogoffPopup,
  FormGroupLocale
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
