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
          :column-label="$i18n.t('PKI Provider Name')"
          :disabled="!isNew && !isClone"
        />

        <form-group-description namespace="description"
          :column-label="$i18n.t('Description')"
        />

        <form-group-enforce namespace="enforce"
          :column-label="$i18n.t('Enforce')"
          :text="$i18n.t('Whether or not the provisioner should be enforced. This will trigger checks to validate the device is compliant with the provisioner during RADIUS authentication and on the captive portal.')"
        />

        <form-group-auto-register namespace="autoregister"
          :column-label="$i18n.t('Auto register')"
          :text="$i18n.t('Whether or not devices should be automatically registered on the network if they are authorized in the provisioner.')"
        />

        <form-group-apply-role namespace="apply_role"
          :column-label="$i18n.t('Apply role')"
          :text="$i18n.t('When enabled, this will apply the configured role to the endpoint if it is authorized in the provisioner.')"
        />

        <form-group-role-to-apply namespace="role_to_apply"
          :column-label="$i18n.t('Role to apply')"
          :text="$i18n.t(`When 'Apply role' is enabled, this defines the role to apply when the device is authorized with the provisioner.`)"
        />

        <form-group-category namespace="category"
          :column-label="$i18n.t('Roles')"
          :text="$i18n.t('Nodes with the selected roles will be affected.')"
        />

        <form-group-oses namespace="oses"
          :column-label="$i18n.t('OS')"
          :text="$i18n.t('Nodes with the selected OS will be affected.')"
        />


        <form-group-client-identifier namespace="client_id"
          :column-label="$i18n.t('Client Key')"
        />

        <form-group-client-secret namespace="client_secret"
          :column-label="$i18n.t('Client Secret')"
        />

        <form-group-host namespace="host"
          :column-label="$i18n.t('Host')"
        />

        <form-group-port namespace="port"
          :column-label="$i18n.t('Port')"
        />

        <form-group-protocol namespace="protocol"
          :column-label="$i18n.t('Protocol')"
        />

        <form-group-access-token namespace="access_token"
          :column-label="$i18n.t('Access token')"
        />

        <form-group-refresh-token namespace="refresh_token"
          :column-label="$i18n.t('Refresh token')"
        />

        <form-group-agent-download-uri namespace="agent_download_uri"
          :column-label="$i18n.t('Agent download URI')"
        />
      </base-form-tab>
      <base-form-tab :title="$i18n.t('Compliance')">
        <form-group-non-compliance-security-event namespace="non_compliance_security_event"
          :column-label="$i18n.t('Non compliance security event')"
          :text="$i18n.t('Which security event should be raised when non compliance is detected.')"
        />

        <form-group-critical-issues-threshold namespace="critical_issues_threshold"
          :column-label="$i18n.t('Critical issues threshold')"
          :text="$i18n.t('The minimum number of critical issues a device needs to have before it gets isolated. 0 deactivates it.')"
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
  FormGroupAccessToken,
  FormGroupAgentDownloadUri,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupCriticalIssuesThreshold,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupNonComplianceSecurityEvent,
  FormGroupOses,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupRefreshToken,
  FormGroupRoleToApply
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupAccessToken,
  FormGroupAgentDownloadUri,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupClientIdentifier,
  FormGroupClientSecret,
  FormGroupCriticalIssuesThreshold,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupNonComplianceSecurityEvent,
  FormGroupOses,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupRefreshToken,
  FormGroupRoleToApply
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-opswat',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
