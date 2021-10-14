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
          :column-label="$i18n.t('Provisioner ID')"
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

        <form-group-host namespace="host"
          :column-label="$i18n.t('Host')"
        />

        <form-group-port namespace="port"
          :column-label="$i18n.t('Port')"
        />

        <form-group-protocol namespace="protocol"
          :column-label="$i18n.t('Protocol')"
        />

        <form-group-username namespace="username"
          :column-label="$i18n.t('Username')"
        />

        <form-group-password namespace="password"
          :column-label="$i18n.t('Password')"
        />

      </base-form-tab>
      <base-form-tab :title="$i18n.t('Compliance')">
        <form-group-non-compliance-security-event namespace="non_compliance_security_event"
          :column-label="$i18n.t('Non compliance security event')"
          :text="$i18n.t('Which security event should be raised when non compliance is detected.')"
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
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupNonComplianceSecurityEvent,
  FormGroupOses,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupUsername,
  FormGroupPassword,
  FormGroupRoleToApply
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupNonComplianceSecurityEvent,
  FormGroupOses,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupUsername,
  FormGroupPassword,
  FormGroupRoleToApply
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-rest',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
