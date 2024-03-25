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

    <form-group-ssid :column-label="$i18n.t('SSID')"
                     namespace="ssid"
    />

    <form-group-oses :column-label="$i18n.t('OS')"
                     :text="$i18n.t('Nodes with the selected OS will be affected.')"
                     namespace="oses"
    />

    <form-group-rules :column-label="$i18n.t('Rules')"
                     :text="$i18n.t('Rules to apply.')"
                     namespace="rules"
    />

    <form-group-dpsk-use-local-password
      :column-label="$i18n.t('Reuse the local password for DPSK')"
      :text="$i18n.t('When DPSK is enabled and a local account with a plaintext password exists for the user, then it will reuse this password instead of generating a new PSK. This feature will only work with local users that have a plaintext password entry.')"
      disabled-value="disabled"
      enabled-value="enabled"
      namespace="dpsk_use_local_password"
    />

    <form-group-psk-size :column-label="$i18n.t('PSK length')"
                         :text="$i18n.t('This is the length of the PSK key you want to generate. The minimum length is eight characters.')"
                         disabled-value="disabled"
                         enabled-value="enabled"
                         namespace="psk_size"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
import {
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupDpskUseLocalPassword,
  FormGroupEnforce,
  FormGroupIdentifier,
  FormGroupOses,
  FormGroupPskSize,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupSsid
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

const components = {
  BaseForm,

  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupDpskUseLocalPassword,
  FormGroupEnforce,
  FormGroupIdentifier,
  FormGroupOses,
  FormGroupPskSize,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupSsid
}

// @vue/component
export default {
  name: 'form-type-dpsk',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
