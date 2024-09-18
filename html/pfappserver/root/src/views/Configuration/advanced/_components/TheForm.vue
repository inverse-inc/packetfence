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
                             enabled-value="enabled"
                             disabled-value="disabled"
    />

    <form-group-admin-csp-security-headers namespace="admin_csp_security_headers"
                                           :column-label="$i18n.t('CSP headers for Admin')"
                                           :text="$i18n.t('(Experimental) Enforce Content-Security-Policy (CSP) HTTP response header in admin interface.')"
                                           enabled-value="enabled"
                                           disabled-value="disabled"
    />

    <form-group-portal-csp-security-headers namespace="portal_csp_security_headers"
                                            :column-label="$i18n.t('CSP headers for Captive portal')"
                                            :text="$i18n.t('(Experimental) Enforce Content-Security-Policy (CSP) HTTP response header in captive portal interface.')"
                                            enabled-value="enabled"
                                            disabled-value="disabled"
    />

    <form-group-scan-on-accounting namespace="scan_on_accounting"
                                   :column-label="$i18n.t('Scan on accounting')"
                                   :text="$i18n.t('Trigger scan engines on accounting.')"
                                   enabled-value="enabled"
                                   disabled-value="disabled"
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
                                :column-label="$i18n.t('LDAP Attributes')"
                                :text="$i18n.t('List of LDAP attributes that can be used in the sources configuration.')"
    />
    <b-row v-if="impliedLdapAttributes.length">
      <b-col cols="3"></b-col>
      <b-col cols="9">
        <div class="alert alert-info mr-3">
          <p><strong>{{ $i18n.t('Built-in LDAP Attributes:') }}</strong></p>
          <span v-for="ldapAttribute in impliedLdapAttributes" :key="ldapAttribute"
                class="badge badge-info mr-1">{{ ldapAttribute }}</span>
        </div>
      </b-col>
    </b-row>

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
                                             enabled-value="enabled"
                                             disabled-value="disabled"
    />

    <form-group-update-iplog-with-external-portal-requests
      namespace="update_iplog_with_external_portal_requests"
      :column-label="$i18n.t('Update the iplog using the external portal requests')"
      :text="$i18n.t('Use the information included in the external portal requests to update the iplog.')"
      enabled-value="enabled"
      disabled-value="disabled"
    />

    <form-group-locationlog-close-on-accounting-stop
      namespace="locationlog_close_on_accounting_stop"
      :column-label="$i18n.t('Close locationlog on accounting stop')"
      :text="$i18n.t('Close the locationlog for a node on accounting stop.')"
      enabled-value="enabled"
      disabled-value="disabled"
    />

    <form-group-timing-stats-level namespace="timing_stats_level"
                                   :column-label="$i18n.t('Stats timing level')"
                                   :text="$i18n.t('Level of timing stats to keep - 0 is the lowest - 10 the highest amount to log. Do not change unless you know what you are doing')"
    />

    <form-group-source-to-send-sms-when-creating-users
      namespace="source_to_send_sms_when_creating_users"
      :column-label="$i18n.t('SMS Source for sending user create messages')"
      :text="$i18n.t('The source to use to send an SMS when creating a user.')"
    />

    <form-group-multihost namespace="multihost"
                          :column-label="$i18n.t('Multihost')"
                          :text="$i18n.t('Ability to manage all active devices from a same switch port.')"
                          enabled-value="enabled"
                          disabled-value="disabled"
    />

    <form-group-active-directory-os-join-check-bypass
      namespace="active_directory_os_join_check_bypass"
      :column-label="$i18n.t('Disable OS AD join check')"
      :text="$i18n.t('Enable to bypass the operating system domain join verification.')"
      enabled-value="enabled"
      disabled-value="disabled"
    />

    <form-group-pfupdate-custom-script-path namespace="pfupdate_custom_script_path"
                                            :column-label="$i18n.t('Path to a custom script called by pfupdate')"
                                            :text="$i18n.t('Path to a custom script called by pfupdate if present.')"
    />

    <form-group-netflow-on-all-networks namespace="netflow_on_all_networks"
                                        :column-label="$i18n.t('NetFlow on all networks')"
                                        :text="$i18n.t('Listen to NetFlow on all networks. Changing this requires to restart pfacct.')"
                                        enabled-value="enabled"
                                        disabled-value="disabled"
    />

    <form-group-accounting-timebucket-size namespace="accounting_timebucket_size"
                                           :column-label="$i18n.t('Accounting timebucket size')"
                                           :text="$i18n.t('Accounting timebucket size. Changing this requires to restart pfacct.')"
    />

    <form-group-openid-attributes namespace="openid_attributes"
                                  :column-label="$i18n.t('OpenID Attributes')"
    />
    <b-row v-if="impliedOpenIdAttributes.length">
      <b-col cols="3"></b-col>
      <b-col cols="9">
        <div class="alert alert-info mr-3">
          <p><strong>{{ $i18n.t('Built-in OpenID Attributes:') }}</strong></p>
          <span v-for="openIdAttribute in impliedOpenIdAttributes" :key="openIdAttribute"
                class="badge badge-info mr-1">{{ openIdAttribute }}</span>
        </div>
      </b-col>
    </b-row>
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import schemaFn from '../schema'
import {
  FormGroupAccountingTimebucketSize,
  FormGroupActiveDirectoryOsJoinCheckBypass,
  FormGroupAdminCspSecurityHeaders,
  FormGroupApiInactivityTimeout,
  FormGroupApiMaxExpiration,
  FormGroupConfigurator,
  FormGroupHashingCost,
  FormGroupHashPasswords,
  FormGroupLanguage,
  FormGroupLdapAttributes,
  FormGroupLocationlogCloseOnAccountingStop,
  FormGroupMultihost,
  FormGroupNetflowOnAllNetworks,
  FormGroupOpenidAttributes,
  FormGroupPffilterProcesses,
  FormGroupPfperlApiProcesses,
  FormGroupPfperlApiTimeout,
  FormGroupPfupdateCustomScriptPath,
  FormGroupPortalCspSecurityHeaders,
  FormGroupScanOnAccounting,
  FormGroupSourceToSendSmsWhenCreatingUsers,
  FormGroupTimingStatsLevel,
  FormGroupUpdateIplogWithAccounting,
  FormGroupUpdateIplogWithExternalPortalRequests
} from './'
import {computed, toRefs} from '@vue/composition-api'
import {useNamespaceMetaImplied} from '@/composables/useMeta'

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
  FormGroupPfupdateCustomScriptPath,
  FormGroupScanOnAccounting,
  FormGroupSourceToSendSmsWhenCreatingUsers,
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

  const {
    meta
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  const impliedLdapAttributes = computed(() => {
    const csv = useNamespaceMetaImplied('ldap_attributes', meta)
    return (csv) ? csv.split(',') : []
  })
  const impliedOpenIdAttributes = computed(() => {
    const array = useNamespaceMetaImplied('openid_attributes', meta)
    return (array && array.length) ? array : []
  })

  return {
    schema,
    impliedLdapAttributes,
    impliedOpenIdAttributes
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

