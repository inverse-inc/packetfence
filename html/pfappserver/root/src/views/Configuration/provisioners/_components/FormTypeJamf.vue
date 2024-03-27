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

    <form-group-sync-pid :column-label="$i18n.t('Sync PID')"
                         :text="$i18n.t('Whether or not the PID (username) should be synchronized from the provisioner to PacketFence.')"
                         disabled-value="disabled"
                         enabled-value="enabled"
                         namespace="sync_pid"
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

    <form-group-host :column-label="$i18n.t('Host')"
                     namespace="host"
    />

    <form-group-port :column-label="$i18n.t('Port')"
                     namespace="port"
    />

    <form-group-protocol :column-label="$i18n.t('Protocol')"
                         namespace="protocol"
    />

    <form-group-api-username :column-label="$i18n.t('API username')"
                             namespace="api_username"
    />

    <form-group-api-password :column-label="$i18n.t('API password')"
                             namespace="api_password"
    />

    <form-group-device-type-detection :column-label="$i18n.t('Automatic device detection')"
                                      disabled-value="disabled"
                                      enabled-value="enabled"
                                      namespace="device_type_detection"
    />

    <form-group-query-computers :column-label="$i18n.t('Query JAMF computers inventory')"
                                disabled-value="disabled"
                                enabled-value="enabled"
                                namespace="query_computers"
    />

    <form-group-query-mobile-devices :column-label="$i18n.t('Query JAMF mobile devices inventory')"
                                     disabled-value="disabled"
                                     enabled-value="enabled"
                                     namespace="query_mobiledevices"
    />
  </base-form>
</template>
<script>
import {BaseForm} from '@/components/new/'
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
  FormGroupPort,
  FormGroupProtocol,
  FormGroupQueryComputers,
  FormGroupQueryMobileDevices,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupSyncPid
} from './'
import {useForm as setup, useFormProps as props} from '../_composables/useForm'

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
  FormGroupPort,
  FormGroupProtocol,
  FormGroupQueryComputers,
  FormGroupQueryMobileDevices,
  FormGroupRoleToApply,
  FormGroupRules,
  FormGroupSyncPid
}

// @vue/component
export default {
  name: 'form-type-jamf',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
