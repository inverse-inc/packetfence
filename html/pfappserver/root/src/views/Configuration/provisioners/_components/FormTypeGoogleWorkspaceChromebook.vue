<template>
  <base-form
    :form="form"
    :isLoading="isLoading"
    :meta="meta"
    :schema="schema"
  >
    <form-group-identifier :column-label="$i18n.t('Provisioning ID')"
                           :disabled="!isNew && !isClone"
                           namespace="id"
    />

    <form-group-description :column-label="$i18n.t('Description')"
                            namespace="description"
    />

    <form-group-enforce :column-label="$i18n.t('Enforce')"
                        :text="$i18n.t('Whether or not the provisioner should be enforced. This will trigger checks to validate the device is compliant with the provisioner during RADIUS authentication and on the captive portal.')"
                        disabled-value="disabled"
                        enabled-value="enabled"
                        namespace="enforce"
    />

    <form-group-auto-register :column-label="$i18n.t('Auto register')"
                              :text="$i18n.t('Whether or not devices should be automatically registered on the network if they are authorized in the provisioner.')"
                              disabled-value="disabled"
                              enabled-value="enabled"
                              namespace="autoregister"
    />

    <form-group-apply-role :column-label="$i18n.t('Apply role')"
                           :text="$i18n.t('When enabled, this will apply the configured role to the endpoint if it is authorized in the provisioner.')"
                           disabled-value="disabled"
                           enabled-value="enabled"
                           namespace="apply_role"
    />

    <form-group-role-to-apply :column-label="$i18n.t('Role to apply')"
                              :text="$i18n.t(`When 'Apply role' is enabled, this defines the role to apply when the device is authorized with the provisioner.`)"
                              namespace="role_to_apply"
    />

    <form-group-category :column-label="$i18n.t('Roles')"
                         :text="$i18n.t('Nodes with the selected roles will be affected.')"
                         namespace="category"
    />

    <form-group-oses :column-label="$i18n.t('OS')"
                     :text="$i18n.t('Nodes with the selected OS will be affected.')"
                     namespace="oses"
    />

    <form-group-rules :column-label="$i18n.t('Rules')"
                     :text="$i18n.t('Rules to apply.')"
                     namespace="rules"
    />

    <form-group-non-compliance-security-event :column-label="$i18n.t('Non compliance security event')"
                                              :text="$i18n.t('Which security event should be raised when non compliance is detected.')"
                                              namespace="non_compliance_security_event"
    />

    <form-group-user :column-label="$i18n.t('User')"
                     :text="$i18n.t('User the service account will impersonate.')"
                     namespace="user"
    />

    <form-group-customer-id :column-label="$i18n.t('Customer ID')"
                            :text="$i18n.t('Customer ID.')"
                            namespace="customerId"
    />

    <form-group-service-account :column-label="$i18n.t('Service Account JSON data')"
                                :text="$i18n.t('Service Account JSON data.')"
                                namespace="service_account"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
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
  FormGroupRules,
  FormGroupServiceAccount,
  FormGroupUser,
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

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
  FormGroupRules,
  FormGroupServiceAccount,
  FormGroupUser,
}

// @vue/component
export default {
  name: 'form-type-accept',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
