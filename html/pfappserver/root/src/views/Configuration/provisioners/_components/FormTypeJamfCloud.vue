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

    <form-group-sync-pid namespace="sync_pid"
      :column-label="$i18n.t('Sync PID')"
      :text="$i18n.t('Whether or not the PID (username) should be synchronized from the provisioner to PacketFence.')"
    />

    <form-group-category namespace="category"
      :column-label="$i18n.t('Roles')"
      :text="$i18n.t('Nodes with the selected roles will be affected.')"
    />

    <form-group-oses namespace="oses"
      :column-label="$i18n.t('OS')"
      :text="$i18n.t('Nodes with the selected OS will be affected.')"
    />

    <form-group-rules namespace="rules"
      :column-label="$i18n.t('Rules')"
      :text="$i18n.t('Rules to apply.')"
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

    <form-group-api-username namespace="api_username"
      :column-label="$i18n.t('API username')"
    />

    <form-group-api-password namespace="api_password"
      :column-label="$i18n.t('API password')"
    />

    <form-group-device-type-detection namespace="device_type_detection"
      :column-label="$i18n.t('Automatic device detection')"
    />

    <form-group-query-computers namespace="query_computers"
      :column-label="$i18n.t('Query JAMF computers inventory')"
    />

    <form-group-query-mobile-devices namespace="query_mobiledevices"
      :column-label="$i18n.t('Query JAMF mobile devices inventory')"
    />
  </base-form>
</template>
<script>
import { BaseForm } from '@/components/new/'
import {
  FormGroupApiPassword,
  FormGroupApiUsername,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupDeviceTypeDetection,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupOses,
  FormGroupRules,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupQueryComputers,
  FormGroupQueryMobileDevices,
  FormGroupRoleToApply,
  FormGroupSyncPid
} from './'

const components = {
  BaseForm,

  FormGroupApiPassword,
  FormGroupApiUsername,
  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupDeviceTypeDetection,
  FormGroupEnforce,
  FormGroupHost,
  FormGroupIdentifier,
  FormGroupOses,
  FormGroupRules,
  FormGroupPort,
  FormGroupProtocol,
  FormGroupQueryComputers,
  FormGroupQueryMobileDevices,
  FormGroupRoleToApply,
  FormGroupSyncPid
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-jamfCloud',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
