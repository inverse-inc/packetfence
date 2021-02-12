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

    <form-group-ssid namespace="ssid"
      :column-label="$i18n.t('SSID')"
    />

    <form-group-oses namespace="oses"
      :column-label="$i18n.t('OS')"
      :text="$i18n.t('Nodes with the selected OS will be affected.')"
    />

    <form-group-dpsk-use-local-password
      namespace="dpsk_use_local_password"
      :column-label="$i18n.t('Reuse the local password for DPSK')"
      :text="$i18n.t('When DPSK is enabled and a local account with a plaintext password exists for the user, then it will reuse this password instead of generating a new PSK. This feature will only work with local users that have a plaintext password entry.')"
    />

    <form-group-psk-size namespace="psk_size"
      :column-label="$i18n.t('PSK length')"
      :text="$i18n.t('This is the length of the PSK key you want to generate. The minimum length is eight characters.')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
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
  FormGroupSsid
} from './'

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
  FormGroupSsid
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-dpsk',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
