<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
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

    <form-group-windows-agent-download-uri namespace="windows_agent_download_uri"
      :column-label="$i18n.t('Windows agent download URI')"
    />

    <form-group-mac-osx-agent-download-uri namespace="mac_osx_agent_download_uri"
      :column-label="$i18n.t('Mac OSX agent download URI')"
    />

    <form-group-linux-agent-download-uri namespace="linux_agent_download_uri"
      :column-label="$i18n.t('Linux agent download URI')"
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
  FormGroupEnforce,
  FormGroupIdentifier,
  FormGroupLinuxAgentDownloadUri,
  FormGroupMacOsxAgentDownloadUri,
  FormGroupOses,
  FormGroupRoleToApply,
  FormGroupWindowsAgentDownloadUri
} from './'

const components = {
  BaseForm,

  FormGroupApplyRole,
  FormGroupAutoRegister,
  FormGroupCategory,
  FormGroupDescription,
  FormGroupEnforce,
  FormGroupIdentifier,
  FormGroupLinuxAgentDownloadUri,
  FormGroupMacOsxAgentDownloadUri,
  FormGroupOses,
  FormGroupRoleToApply,
  FormGroupWindowsAgentDownloadUri
}

import { useForm as setup, useFormProps as props } from '../_composables/useForm'

// @vue/component
export default {
  name: 'form-type-intune',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
