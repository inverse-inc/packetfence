<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <form-group-identifier namespace="id"
      :column-label="$i18n.t('Provisioning ID')"
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

   <form-group-non-compliance-security-event namespace="non_compliance_security_event"
     :column-label="$i18n.t('Non compliance security event')"
     :text="$i18n.t('Which security event should be raised when non compliance is detected.')"
   />

    <form-group-expires-in namespace="expires_in"
      :column-label="$i18n.t('Token Expires In')"
      :text="$i18n.t('The amount of seconds of the suggested expiration time.')"
    />

    <form-group-expires-in namespace="expires_jitter"
      :column-label="$i18n.t('Token Expires Jitter')"
      :text="$i18n.t('The token expiration jitter.')"
    />

    <form-group-user namespace="user"
      :column-label="$i18n.t('User')"
      :text="$i18n.t('User the service account will impersonate.')"
    />

    <form-group-customer-id namespace="customerId"
      :column-label="$i18n.t('Customer ID')"
      :text="$i18n.t('Customer ID.')"
    />

    <form-group-service-account namespace="service_account"
      :column-label="$i18n.t('Service Account JSON data')"
      :text="$i18n.t('Service Account JSON data.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupCustomerId,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupExpiresIn,
  FormGroupExpiresJitter,
  FormGroupIdentifier,
  FormGroupNonComplianceSecurityEvent,
  FormGroupOses,
  FormGroupRoleToApply,
  FormGroupServiceAccount,
  FormGroupUser,
} from './'

const components = {
  BaseForm,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupCustomerId,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupExpiresIn,
  FormGroupExpiresJitter,
  FormGroupIdentifier,
  FormGroupNonComplianceSecurityEvent,
  FormGroupOses,
  FormGroupRoleToApply,
  FormGroupServiceAccount,
  FormGroupUser,
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-accept',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
