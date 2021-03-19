<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-language namespace="language"
      :column-label="$i18n.t('Language of communication')"
      :text="$i18n.t('Language choice for the communication with administrators.')"
    />

    <form-group-api-inactivity-timeout namespace="api_inactivity_timeout"
      :column-label="$i18n.t('API inactivity timeout')"
      :text="$i18n.t('The inactivity timeout of an API token. Requires to restart the api-frontend service to be fully effective.')"
    />

    <form-group-api-max-expiration namespace="api_max_expiration"
      :column-label="$i18n.t('API token max expiration')"
      :text="$i18n.t('The maximum amount of time an API token can be valid. Requires to restart the api-frontend service to be fully effective.')"
    />

    <form-group-configurator namespace="configurator"
      :column-label="$i18n.t('Configurator')"
      :text="$i18n.t('Enable the Configurator and the Configurator API.')"
    />

    <form-group-admin-csp-security-headers namespace="admin_csp_security_headers"
      :column-label="$i18n.t('CSP headers for Admin')"
      :text="$i18n.t('(Experimental) Enforce Content-Security-Policy (CSP) HTTP response header in admin interface.')"
    />

    <form-group-portal-csp-security-headers namespace="portal_csp_security_headers"
      :column-label="$i18n.t('CSP headers for Captive portal')"
      :text="$i18n.t('(Experimental) Enforce Content-Security-Policy (CSP) HTTP response header in captive portal interface.')"
    />

    <form-group-sso-on-access-reevaluation namespace="sso_on_access_reevaluation"
      :column-label="$i18n.t('SSO on access reevaluation')"
      :text="$i18n.t('Trigger Single-Sign-On (Firewall SSO) on access reevaluation.')"
    />

    <form-group-scan-on-accounting namespace="scan_on_accounting"
      :column-label="$i18n.t('Scan on accounting')"
      :text="$i18n.t('Trigger scan engines on accounting.')"
    />

    <form-group-sso-on-accounting namespace="sso_on_accounting"
      :column-label="$i18n.t('SSO on accounting')"
      :text="$i18n.t('Trigger Single-Sign-On (Firewall SSO) on accounting.')"
    />

    <form-group-sso-on-dhcp namespace="sso_on_dhcp"
      :column-label="$i18n.t('SSO on DHCP')"
      :text="$i18n.t('Trigger Single-Sign-On (Firewall SSO) on dhcp.')"
    />

    <form-group-hash-passwords namespace="hash_passwords"
      :column-label="$i18n.t('Database passwords hashing method')"
      :text="$i18n.t('The algorithm used to hash the passwords in the database. This will only affect newly created or reset passwords.')"
    />

    <form-group-hashing-cost namespace="hashing_cost"
      :column-label="$i18n.t('Hashing Cost')"
      :text="$i18n.t('The cost factor to apply to the password hashing if applicable. Currently only applies to bcrypt.')"
    />

    <form-group-ldap-attributes namespace="ldap_attributes"
      :column-label="$i18n.t('LDAP Attribute')"
      :text="$i18n.t('List of LDAP attributes that can be used in the sources configuration.')"
    />

    <form-group-pffilter-processes namespace="pffilter_processes"
      :column-label="$i18n.t('PfFilter Processes')"
      :text="$i18n.t('Amount of pffilter processes to start.')"
    />

    <form-group-pfperl-api-processes namespace="pfperl_api_processes"
      :column-label="$i18n.t('PfPerl API Processes')"
      :text="$i18n.t('Amount of pfperl-api processes to start.')"
    />

    <form-group-pfperl-api-timeout namespace="pfperl_api_timeout"
      :column-label="$i18n.t('PfPerl API Timeout')"
      :text="$i18n.t('The timeout in seconds for an API request.')"
    />

    <form-group-update-iplog-with-accounting namespace="update_iplog_with_accounting"
      :column-label="$i18n.t('Update the iplog using the accounting')"
      :text="$i18n.t('Use the information included in the accounting to update the iplog.')"
    />

    <form-group-update-iplog-with-external-portal-requests namespace="update_iplog_with_external_portal_requests"
      :column-label="$i18n.t('Update the iplog using the external portal requests')"
      :text="$i18n.t('Use the information included in the external portal requests to update the iplog.')"
    />

    <form-group-locationlog-close-on-accounting-stop namespace="locationlog_close_on_accounting_stop"
      :column-label="$i18n.t('Close locationlog on accounting stop')"
      :text="$i18n.t('Close the locationlog for a node on accounting stop.')"
    />

    <form-group-timing-stats-level namespace="timing_stats_level"
      :column-label="$i18n.t('Stats timing level')"
      :text="$i18n.t('Level of timing stats to keep - 0 is the lowest - 10 the highest amount to log. Do not change unless you know what you are doing')"
    />

    <form-group-source-to-send-sms-when-creating-users namespace="source_to_send_sms_when_creating_users"
      :column-label="$i18n.t('SMS Source for sending user create messages')"
      :text="$i18n.t('The source to use to send an SMS when creating a user.')"
    />

    <form-group-multihost namespace="multihost"
      :column-label="$i18n.t('Multihost')"
      :text="$i18n.t('Ability to manage all active devices from a same switch port.')"
    />

    <form-group-active-directory-os-join-check-bypass namespace="active_directory_os_join_check_bypass"
      :column-label="$i18n.t('Disable OS AD join check')"
      :text="$i18n.t('Enable to bypass the operating system domain join verification.')"
    />

    <form-group-netflow-on-all-networks namespace="netflow_on_all_networks"
      :column-label="$i18n.t('NetFlow on all networks')"
      :text="$i18n.t('Listen to NetFlow on all networks. Changing this requires to restart pfacct.')"
    />

    <form-group-accounting-timebucket-size namespace="accounting_timebucket_size"
      :column-label="$i18n.t('Accounting timebucket size')"
      :text="$i18n.t('Accounting timebucket size. Changing this requires to restart pfacct.')"
    />

    <form-group-openid-attributes namespace="openid_attributes"
      :column-label="$i18n.t('OpenID Attributes')"
    />
  </base-form>
</template>
<script>
import { computed } from '@vue/composition-api'
import {
  BaseForm
} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAccountingTimebucketSize,
  FormGroupActiveDirectoryOsJoinCheckBypass,
  FormGroupAdminCspSecurityHeaders,
  FormGroupApiInactivityTimeout,
  FormGroupApiMaxExpiration,
  FormGroupConfigurator,
  FormGroupHashPasswords,
  FormGroupHashingCost,
  FormGroupLanguage,
  FormGroupLdapAttributes,
  FormGroupLocationlogCloseOnAccountingStop,
  FormGroupMultihost,
  FormGroupNetflowOnAllNetworks,
  FormGroupOpenidAttributes,
  FormGroupPffilterProcesses,
  FormGroupPfperlApiProcesses,
  FormGroupPfperlApiTimeout,
  FormGroupPortalCspSecurityHeaders,
  FormGroupScanOnAccounting,
  FormGroupSourceToSendSmsWhenCreatingUsers,
  FormGroupSsoOnAccessReevaluation,
  FormGroupSsoOnAccounting,
  FormGroupSsoOnDhcp,
  FormGroupTimingStatsLevel,
  FormGroupUpdateIplogWithAccounting,
  FormGroupUpdateIplogWithExternalPortalRequests
} from './'

const components = {
  BaseForm,

  FormGroupAccountingTimebucketSize,
  FormGroupActiveDirectoryOsJoinCheckBypass,
  FormGroupAdminCspSecurityHeaders,
  FormGroupApiInactivityTimeout,
  FormGroupApiMaxExpiration,
  FormGroupConfigurator,
  FormGroupHashPasswords,
  FormGroupHashingCost,
  FormGroupLanguage,
  FormGroupLdapAttributes,
  FormGroupLocationlogCloseOnAccountingStop,
  FormGroupMultihost,
  FormGroupNetflowOnAllNetworks,
  FormGroupOpenidAttributes,
  FormGroupPffilterProcesses,
  FormGroupPfperlApiProcesses,
  FormGroupPfperlApiTimeout,
  FormGroupPortalCspSecurityHeaders,
  FormGroupScanOnAccounting,
  FormGroupSourceToSendSmsWhenCreatingUsers,
  FormGroupSsoOnAccessReevaluation,
  FormGroupSsoOnAccounting,
  FormGroupSsoOnDhcp,
  FormGroupTimingStatsLevel,
  FormGroupUpdateIplogWithAccounting,
  FormGroupUpdateIplogWithExternalPortalRequests
}

export const props = {
  form: {
    type: Object
  },
  meta: {
    type: Object
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

