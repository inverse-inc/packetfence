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

    <form-group-username namespace="username"
      :column-label="$i18n.t('Username')"
    />

    <form-group-password namespace="password"
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

    <form-group-table-for-mac namespace="table_for_mac"
      :column-label="$i18n.t('MAC table name')"
    />

    <form-group-table-for-agent namespace="table_for_agent"
      :column-label="$i18n.t('Agent table name')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupApplyRole,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupOses,
  FormGroupPassword,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupRoleToApply,
  FormGroupTableForAgent,
  FormGroupTableForMac,
  FormGroupUsername
} from './'

const components = {
  BaseForm,

  FormGroupApplyRole,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupOses,
  FormGroupPassword,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupRoleToApply,
  FormGroupTableForAgent,
  FormGroupTableForMac,
  FormGroupUsername
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-servicenow',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
